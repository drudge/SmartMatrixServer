const mqtt = require('mqtt')
const fs = require('fs');
const { ToadScheduler, SimpleIntervalJob, Task } = require('toad-scheduler');
const { Watchdog } = require("watchdog");
const WebP = require('node-webpmux');
const { exit } = require('process');
const {spawn} = require("child_process");

globalThis.require = require;
globalThis.fs = require("fs");
globalThis.TextEncoder = require("util").TextEncoder;
globalThis.TextDecoder = require("util").TextDecoder;
globalThis.fetch = fetch;
globalThis.Headers = fetch.Headers;
globalThis.Response = fetch.Response;
globalThis.Request = fetch.Request;

globalThis.performance = {
	now() {
		const [sec, nsec] = process.hrtime();
		return sec * 1000 + nsec / 1000000;
	},
};

const crypto = require("crypto");
globalThis.crypto = {
	getRandomValues(b) {
		crypto.randomFillSync(b);
	},
};

require("./wasm_exec");

/*

Required environment variables for applet-sender to function
MQTT_[HOSTNAME,USERNAME,PASSWORD]
REDIS_[HOSTNAME,USERNAME,PASSWORD],
[CONFIG,APPLET]_FOLDER

*/

const client  = mqtt.connect(process.env.MQTT_HOSTNAME, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD
});

let { CONFIG_FOLDER } = process.env
if(CONFIG_FOLDER === undefined) {
    console.log("CONFIG_FOLDER not set, using `/config` ...");
    CONFIG_FOLDER = "./config";
}

let { APPLET_FOLDER } = process.env
if(APPLET_FOLDER === undefined) {
    console.log("APPLET_FOLDER not set, using `/applets` ...");
    APPLET_FOLDER = "./applets";
}

const go = new Go();
go.env = Object.assign({ TMPDIR: require("os").tmpdir() }, process.env);

const scheduler = new ToadScheduler();
let chunkSize = 19950;

let config = {};

const pixletWasm = fs.readFileSync('./pixlet.wasm');

const directory = fs.opendirSync(CONFIG_FOLDER)
let file;

while ((file = directory.readSync()) !== null) {
    let device = file.name.split(".")[0];
    if(device.indexOf("/") != -1) {
        device = device.split("/")[1];
    }

    let scheduleFilePath = `${CONFIG_FOLDER}/${device.toUpperCase()}.json`;
    if(!fs.existsSync(scheduleFilePath)) {
        console.log("Schedule file for device does not exist!");
        return;
    }

    let schedule = fs.readFileSync(scheduleFilePath);

    config[device] = {
        currentApplet: -1,
        currentAppletStartedAt: 0,
        connected: false,
        sendingStatus: {
            timed_out: false,
            retries: 0,
            currentBufferPos: 0,
            buf: null,
            hasSentLength: false,
            isCurrentlySending: false
        },
        jobRunning: false,
        offlineWatchdog: null,
        schedule: JSON.parse(schedule)
    }
}

directory.closeSync()

function loadPixlet(wasm) {
    return WebAssembly.instantiate(wasm, go.importObject).then((result) => {
        go.run(result.instance);
        return new Promise(resolve => {
            setTimeout(resolve, 2000);
        })
    });
}

async function getWebPImage(data, width, height) {
    const img = await WebP.Image.getEmptyImage();
    await img.initLib();
    await img.setImageData(data, {
        width,
        height,
    });
    return img;
}

async function buildFrame(img, options = {}) {
    return WebP.Image.generateFrame({
        img, 
        ...options,
    });
}

async function deviceLoop(device) {
    if(config[device].jobRunning || config[device].connected == false) {
        return;
    }

    console.log(`Running device loop for ${device}...`)

    await loadPixlet(pixletWasm);

    config[device].jobRunning = true;

    const nextAppletNeedsRunAt = config[device].currentAppletStartedAt + (config[device].schedule[config[device].currentApplet+1].duration * 1000);

    if(Date.now() > nextAppletNeedsRunAt && !config[device].sendingStatus.isCurrentlySending) {
        config[device].currentApplet++;

        const applet = config[device].schedule[config[device].currentApplet];
        config[device].sendingStatus.isCurrentlySending = true;

        console.log(`Rendering applet ${applet.name}...`)

        let imageData = await render(applet.name, applet.config ?? {}).catch((e) => {
            //upon failure, skip applet and retry.
            console.log(e);
            config[device].currentApplet++;
            config[device].sendingStatus.isCurrentlySending = false;
            if(config[device].currentApplet >= (config[device].schedule.length - 1)) {
                config[device].currentApplet = -1;
            }
            // setTimeout(() => {
            //     deviceLoop(device);
            // }, 5);
        })

        if(config[device].sendingStatus.isCurrentlySending) {
            config[device].sendingStatus.buf = new Uint8Array(imageData);
            config[device].sendingStatus.currentBufferPos = 0;
            config[device].sendingStatus.hasSentLength = false;

            client.publish(`plm/${device}/rx`, "START");

            if(config[device].currentApplet >= (config[device].schedule.length - 1)) {
                config[device].currentApplet = -1;
            }
        }
    }

    config[device].jobRunning = false;
}

function gotDeviceResponse(device, message) {
    config[device].offlineWatchdog.feed();
    if(message == "OK") {
        if(config[device].sendingStatus.currentBufferPos <= config[device].sendingStatus.buf.length) {
            if(config[device].sendingStatus.hasSentLength == false) {
                config[device].sendingStatus.hasSentLength = true;
                client.publish(`plm/${device}/rx`, config[device].sendingStatus.buf.length.toString());
            } else {
                let chunk = config[device].sendingStatus.buf.slice(config[device].sendingStatus.currentBufferPos, config[device].sendingStatus.currentBufferPos+chunkSize);
                config[device].sendingStatus.currentBufferPos += chunkSize;
                client.publish(`plm/${device}/rx`, chunk);
            }
        } else {
            client.publish(`plm/${device}/rx`, "FINISH");
        }
    } else {
        if(message == "DECODE_ERROR" || message == "PUSHED") {
            config[device].currentAppletStartedAt = Date.now();
            config[device].sendingStatus.isCurrentlySending = false;
            config[device].sendingStatus.hasSentLength = false;
            config[device].sendingStatus.currentBufferPos = 0;
            config[device].sendingStatus.buf = null;
        } else if(message == "DEVICE_BOOT") {
            console.log("device is online!");
            config[device].sendingStatus.isCurrentlySending = false;
            config[device].sendingStatus.hasSentLength = false;
            config[device].sendingStatus.currentBufferPos = 0;
            config[device].sendingStatus.buf = null;
        } else if(message == "TIMEOUT") {
            console.log("device rx timeout!");
            config[device].sendingStatus.isCurrentlySending = false;
            config[device].sendingStatus.hasSentLength = false;
            config[device].sendingStatus.currentBufferPos = 0;
            config[device].sendingStatus.buf = null;
        }
        config[device].connected = true;
    }
}

function toArrayBuffer(buffer) {
    const arrayBuffer = new ArrayBuffer(buffer.length);
    const view = new Uint8Array(arrayBuffer);
    for (let i = 0; i < buffer.length; ++i) {
        view[i] = buffer[i];
    }
    return arrayBuffer;
}

function render(name, config) {
    return new Promise(async (resolve, reject) => {

        let configValues = [];
        for(const [name, v] of Object.entries(config)) {
            configValues.push({
                name,
                value: typeof v === 'object' ? JSON.stringify(v) : v 
            });
        }
        let outputError = "";
        let unedited = await fs.promises.readFile(`${APPLET_FOLDER}/${name}/${name}.star`, { encoding: 'utf8'});
        // if(unedited.indexOf(`load("cache.star", "cache")`) != -1) {
        //     const redis_connect_string = `cache_redis.connect("${ process.env.REDIS_HOSTNAME }", "${ process.env.REDIS_USERNAME }", "${ process.env.REDIS_PASSWORD }")`
        //     unedited = unedited.replaceAll(`load("cache.star", "cache")`, `load("cache_redis.star", "cache_redis")\n${redis_connect_string}`);
        //     unedited = unedited.replaceAll(`cache.`, `cache_redis.`);
        // }
        // fs.writeFileSync(`${APPLET_FOLDER}/${name}/${name}.tmp.star`, unedited)
        const { frames, delay } =  await pixlet.render(unedited, configValues);
    
        const outFrames = [];
        let width = 64;
        let height = 32;
    
        console.log(`Rendering ${frames.length} frames`);
        for (let i = 0; i < frames.length; i++) {
            const rawFrame = frames[i];
            // console.log(rawFrame);
    
            const img = await getWebPImage(rawFrame.data, width, height);
            const frame = await buildFrame(img, {
                delay,
            });
            outFrames.push(frame);
            width = rawFrame.width;
            height = rawFrame.height;
        }
    
        const webpData = await WebP.Image.save(null, {
            frames: outFrames,
            width,
            height,
        });

        resolve(toArrayBuffer(webpData));
    })
}

client.on('connect', function () {
    for(const [device, _] of Object.entries(config)) {
        client.subscribe(`plm/${device}/tx`, function (err) {
            if (!err) {
                client.publish(`plm/${device}/rx`, "PING");
                
                //Setup job to work on device.
                const task = new Task('simple task', () => {
                    deviceLoop(device)
                });
                
                const job = new SimpleIntervalJob(
                    { seconds: 15, runImmediately: true },
                    task,
                    { id: `loop_${device}` }
                );

                scheduler.addSimpleIntervalJob(job);

                const dog = new Watchdog(60000);
                dog.on('reset', () => {
                    console.log(`Device ${device} disconnected.`);
                    config[device].connected = false;
                    config[device].sendingStatus.isCurrentlySending = false;
                    config[device].sendingStatus.hasSentLength = false;
                    config[device].sendingStatus.currentBufferPos = 0;
                    config[device].sendingStatus.buf = null;
                })
                dog.on('feed',  () => {
                    config[device].connected = true;
                })

                config[device].offlineWatchdog = dog;
            } else {
                console.log(`Couldn't subscribe to ${device} response channel.`);
            }
        })
    }
});

client.on("disconnect", function() {
    scheduler.stop()
    exit(1);
});

client.on("error", function() {
    scheduler.stop()
    exit(1);
});

client.on("close", function() {
    scheduler.stop()
    exit(1);
});

client.on('message', function (topic, message) {
    if(topic.indexOf("tx") != -1) {
      const device = topic.split("/")[1];
      gotDeviceResponse(device, message);
    }
})