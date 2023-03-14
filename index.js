const mqtt = require('mqtt');
const fs = require('fs');
const ms = require('ms');
const { ToadScheduler, SimpleIntervalJob, Task } = require('toad-scheduler');
const { Watchdog } = require("watchdog");
const { exit } = require('process');
const { spawn } = require("child_process");
const { debuglog } = require('util');

const debug = debuglog("smart-matrix-server");

/*

Required environment variables for applet-sender to function
MQTT_[HOSTNAME,USERNAME,PASSWORD]
REDIS_[HOSTNAME,USERNAME,PASSWORD],
[CONFIG,APPLET]_FOLDER

*/

const client  = mqtt.connect(process.env.MQTT_HOSTNAME, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
});

const DEVICE_TOPIC_PREFIX = process.env.SMARTMATRIX_TOPIC_PREFIX || 'plm';
console.log("Using device topic prefix:", DEVICE_TOPIC_PREFIX);
let { CONFIG_FOLDER } = process.env;
if(CONFIG_FOLDER === undefined) {
    console.log("CONFIG_FOLDER not set, using `/config` ...");
    CONFIG_FOLDER = "/config";
}

let { APPLET_FOLDER } = process.env;
if(APPLET_FOLDER === undefined) {
    console.log("APPLET_FOLDER not set, using `/applets` ...");
    APPLET_FOLDER = "/applets";
}
let { DEVICE_TIMEOUT } = process.env;
if(DEVICE_TIMEOUT === undefined) {
    console.log("DEVICE_TIMEOUT not set, using 60 seconds ...");
    DEVICE_TIMEOUT = ms("60s");
}
DEVICE_TIMEOUT = ms(DEVICE_TIMEOUT);

let { DEVICE_LOOP_INTERVAL } = process.env;
if(DEVICE_LOOP_INTERVAL === undefined) {
    console.log("DEVICE_LOOP_INTERVAL not set, using 10 second ...");
    DEVICE_LOOP_INTERVAL = ms("10s");
}
console.log(`Devices will loop every ${DEVICE_LOOP_INTERVAL} seconds`);
DEVICE_LOOP_INTERVAL = ms(DEVICE_LOOP_INTERVAL);

let { DEVICE_PING_INTERVAL } = process.env;
if(DEVICE_PING_INTERVAL === undefined) {
    console.log("DEVICE_PING_INTERVAL not set, using 30 seconds ...");
    DEVICE_PING_INTERVAL = ms("30s");
}
console.log(`Devices will ping every ${DEVICE_PING_INTERVAL} seconds`);
DEVICE_PING_INTERVAL = ms(DEVICE_PING_INTERVAL);

const scheduler = new ToadScheduler();
let chunkSize = 19950;

let config = {};

const directory = fs.opendirSync(CONFIG_FOLDER);
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

    fs.watchFile(scheduleFilePath, () => reloadConfig(device));

    let postProcessFilePath = `${CONFIG_FOLDER}/${device.toUpperCase()}.post.js`;
    let postProcess;
    if(fs.existsSync(postProcessFilePath)) {
        try {
            postProcess = require(postProcessFilePath);
        } catch (error) {
            console.error("Error loading post process file for device", postProcessFilePath, device, error);
        }
    }

    config[device] = {
        pinApplet: false,
        currentApplet: -1,
        currentAppletStartedAt: 0,
        connected: false,
        sendingStatus: {
            timed_out: false,
            retries: 0,
            currentBufferPos: 0,
            buf: null,
            hasSentLength: false,
            isCurrentlySending: false,
        },
        jobRunning: false,
        offlineWatchdog: null,
        schedule: JSON.parse(schedule),
        postProcess,
    };
}

directory.closeSync();

function resetDevice(device) {
    if (!config[device]) {
        debug("Device not found in config", device);
        return;
    }
    config[device].sendingStatus.isCurrentlySending = false;
    config[device].sendingStatus.hasSentLength = false;
    config[device].sendingStatus.currentBufferPos = 0;
    config[device].sendingStatus.buf = null;
}

function reloadConfig(device) {
    const scheduleFilePath = `${CONFIG_FOLDER}/${device.toUpperCase()}.json`;

    if(!fs.existsSync(scheduleFilePath)) {
        console.log("Schedule file for device does not exist!");
        return;
    }

    debug("Reloading config for device", device);

    const schedule = fs.readFileSync(scheduleFilePath);
    config[device].schedule = JSON.parse(schedule);
    config[device].currentApplet = -1;
    config[device].currentAppletStartedAt = 0;
    resetDevice(device);
}

function resetAppletIfNeeded(device) { 
    if (config[device].pinApplet) {
        // debug("Applet pinned, not resetting applet for device", device);
        return;
    }
    if(config[device].currentApplet >= (config[device].schedule.length - 1)) {
        debug("Resetting rotation for device", device);
        config[device].currentApplet = -1;
    }
}

function moveToNextApplet(device) {
    config[device].sendingStatus.isCurrentlySending = false;
    config[device].currentApplet++;
    resetAppletIfNeeded(device);
    setTimeout(() => deviceLoop(device), 5);
}

async function deviceLoop(device) {
    // debug("deviceLoop", device);
    if(config[device].jobRunning || config[device].connected == false) {
        return;
    }

    config[device].jobRunning = true;

    let nextApplet = config[device].currentApplet+1;
    const scheduleLength = config[device].schedule.length;
    if (nextApplet >= scheduleLength) {
        nextApplet = 0;
    }
    const nextAppletNeedsRunAt = config[device].currentAppletStartedAt + (config[device].schedule[nextApplet].duration * 1000);

    if(Date.now() > nextAppletNeedsRunAt && !config[device].sendingStatus.isCurrentlySending) {
        debug("applet pinned? %s", config[device].pinApplet ? "yes" : "no")
        let oldApplet = config[device].currentApplet;
        if (oldApplet === -1) oldApplet = 0;
        if (!config[device].pinApplet) config[device].currentApplet = nextApplet;
        debug("rotation: %i of %i", oldApplet + 1, scheduleLength);
        const applet = config[device].schedule[config[device].currentApplet];
        config[device].sendingStatus.isCurrentlySending = true;

        debug("rendering applet", applet.name, "for device", device);

        let imageData;
        let skipped = false;
        try {
            const res = await render(applet.name, applet.config ?? {});
            imageData = res.imageData;
            skipped = res.skipped;
        } catch (error) {
            debug('error: ', error);
            if (config[device].pinApplet) setPinned(device, false);
            moveToNextApplet(device);
        }

        if (skipped) {
            if (config[device].pinApplet) setPinned(device, false);
            moveToNextApplet(device);
        }

        if(config[device].sendingStatus.isCurrentlySending && imageData) {
            config[device].sendingStatus.buf = new Uint8Array(imageData);
            config[device].sendingStatus.currentBufferPos = 0;
            config[device].sendingStatus.hasSentLength = false;

            publishToDevice(device, "START");

            if (config[device].schedule && config[device].schedule[nextApplet] && typeof config[device].schedule[nextApplet].focus !== 'undefined') {
                config[device].currentApplet = nextApplet;
                setPinned(device, !!config[device].schedule[nextApplet].focus);
            }
            
            if (!config[device].pinApplet) {
                resetAppletIfNeeded(device);
            }
        }

        if (typeof config[device].postProcess === 'function') {
            await config[device].postProcess(applet);
        }
    }

    config[device].jobRunning = false;
}

function togglePinning(device) {
    const newVal = !config[device].pinApplet;
    setPinned(device, newVal);
}

function setPinned(device, pinned) {
    if (config[device].currentApplet === -1) return;
    const applet = config[device].schedule[config[device].currentApplet];
    debug(`${pinned ? 'Pinning' : 'Unpinning'} ${applet.name} applet on device`, device)
    config[device].pinApplet = pinned;

    if (!pinned) {
        resetAppletIfNeeded(device);
    }
}

function pinApplet(device, index) {
    const scheduleLength = config[device].schedule.length;
    if (index >= scheduleLength) {
        debug("Pin failed: Invalid applet index", index, "for device", device);
        return;
    }
    config[device].currentApplet = index;
    setPinned(device, true);
}

function publishToDevice(device, message) {
    return client.publish(`${DEVICE_TOPIC_PREFIX}/${device}/rx`, message);
}

function handleDeviceResponse(device, payload) {
    const message = payload.toString('utf8');
    if (message == "PIN" || message == "UNPIN") {
        togglePinning(device);
    } else if (message.indexOf("PIN:") === 0) {
        const val = message.split("PIN:")[1];
        pinApplet(device, parseInt(val, 10));
    } else if(message === "OK") {
        if(config[device].sendingStatus.buf !== null && config[device].sendingStatus.currentBufferPos <= config[device].sendingStatus.buf.length) {
            if(config[device].sendingStatus.hasSentLength == false) {
                config[device].sendingStatus.hasSentLength = true;
                publishToDevice(device, config[device].sendingStatus.buf.length.toString());
            } else {
                let chunk = config[device].sendingStatus.buf.slice(config[device].sendingStatus.currentBufferPos, config[device].sendingStatus.currentBufferPos+chunkSize);
                config[device].sendingStatus.currentBufferPos += chunkSize;
                publishToDevice(device, chunk);
            }
        } else {
            publishToDevice(device, "FINISH");
        }
    } else {
        if(message === "DECODE_ERROR" || message === "PUSHED") {
            debug(`${device} ${message}`);
            config[device].currentAppletStartedAt = Date.now();
            resetDevice(device);
        } else if(message === "DEVICE_BOOT") {
            debug(`${device} is online!`);
            resetDevice(device);
        } else if(message === "TIMEOUT") {
            debug(`${device} rx timeout!`);
            resetDevice(device);
        }
        config[device].connected = true;
    }
}

function render(name, config) {
    return new Promise(async (resolve, reject) => {
        let configValues = [];
        for(const [k, v] of Object.entries(config)) {
            if(typeof v === 'object') {
                configValues.push(`${k}=${JSON.stringify(v)}`);
            } else {
                configValues.push(`${k}=${v}`);
            }
        }
        let outputError = "";
        let unedited = fs.readFileSync(`${APPLET_FOLDER}/${name}/${name}.star`).toString();

        if (typeof process.env.REDIS_HOSTNAME !== 'undefined') {
            if(unedited.indexOf(`load("cache.star", "cache")`) != -1) {
                const redis_connect_string = `cache_redis.connect("${ process.env.REDIS_HOSTNAME }", "${ process.env.REDIS_USERNAME || '' }", "${ process.env.REDIS_PASSWORD || '' }")`
                unedited = unedited.replaceAll(`load("cache.star", "cache")`, `load("cache_redis.star", "cache_redis")\n${redis_connect_string}`);
                unedited = unedited.replaceAll(`cache.`, `cache_redis.`);
            }
        }
        fs.writeFileSync(`${APPLET_FOLDER}/${name}/${name}.tmp.star`, unedited);

        const renderCommand = spawn('pixlet', ['render', `${APPLET_FOLDER}/${name}/${name}.tmp.star`,...configValues,'-o',`${APPLET_FOLDER}/${name}/${name}.webp`]);
    
        const timeout = setTimeout(() => {
            console.log(`Rendering timed out for ${name}`);
            try {
              process.kill(renderCommand.pid, 'SIGKILL');
            } catch (e) {
              console.log('Could not kill process ^', e);
            }
        }, 10000);

        renderCommand.stdout.on('data', (data) => {
            outputError += data;
        })

        renderCommand.stderr.on('data', (data) => {
            outputError += data;
        })
    
        renderCommand.on('close', (code) => {
            clearTimeout(timeout);
            if (fs.existsSync(`${APPLET_FOLDER}/${name}/${name}.tmp.star`)) {
                fs.unlinkSync(`${APPLET_FOLDER}/${name}/${name}.tmp.star`);
            }
            if(code == 0) {
                if(outputError.indexOf("skip_execution") == -1) {
                    debug(`rendered ${name} successfully!`);
                    resolve({
                        skipped: false,
                        imageData: fs.readFileSync(`${APPLET_FOLDER}/${name}/${name}.webp`),
                    });
                } else {
                    debug(`skipped ${name}!`);
                    resolve({ skipped: true, imageData: null });
                }
            } else {
                console.error(outputError);
                const err = new Error("Applet failed to render");
                err.cause = outputError;
                reject(err);
            }
        });
    })
}

function addJob(scheduler, type, device) {
    let job = null;
    let options = { runImmediately: true };
    const id = `${type}_${device}`;
    if (type == "loop") {
        options = {
            ...options,
            milliseconds: Number.isInteger(DEVICE_LOOP_INTERVAL) ? DEVICE_LOOP_INTERVAL : ms(DEVICE_LOOP_INTERVAL),
        };
        // debug(`Adding loop job for ${device}...`);
        // debug(options);
        job = new SimpleIntervalJob(options, new Task(id, () => deviceLoop(device)), { id });
    } else if (type == "ping") {
        options = {
            ...options,
            milliseconds: Number.isInteger(DEVICE_PING_INTERVAL) ? DEVICE_PING_INTERVAL : ms(DEVICE_PING_INTERVAL),
        };
        // debug(`Adding ping job for ${device}...`);
        // debug(options);
        job = new SimpleIntervalJob(options, new Task(id, () => publishToDevice(device, "PING")), { id });
    }

    if (job !== null && scheduler) {
        scheduler.addSimpleIntervalJob(job);
    }

    return job;
}

function onDeviceConnect() {
    for(const [device, _] of Object.entries(config)) {
        client.subscribe(`${DEVICE_TOPIC_PREFIX}/${device}/tx`, function (err) {
            if (!err) {    
                if (!config[device].offlineWatchdog) {            
                    const dog = new Watchdog(Number.isInteger(DEVICE_TIMEOUT) ? DEVICE_TIMEOUT : ms(DEVICE_TIMEOUT));
                    config[device].offlineWatchdog = dog;
                    dog.on('reset', () => onDeviceDisconnect(device));
                    dog.on('feed', () => onDeviceUpdated(device));
                    addJob(scheduler, "loop", device);
                    addJob(scheduler, "ping", device);
                }
            } else {
                debug(`Couldn't subscribe to ${device} response channel.`);
            }
        });
    }
}

function onDeviceUpdated(device) {
    config[device].connected = true;
}

function onDeviceDisconnect(device) {
    debug(`Device ${device} disconnected.`);
    config[device].connected = false;
    resetDevice(device);
}

function onDeviceMessage(topic, message) {
    if(topic.indexOf("tx") != -1) {
      const device = topic.split("/")[1];
      config[device].offlineWatchdog.feed();
      handleDeviceResponse(device, message);
    }
}

function onGracefulExit(code) {
    debug(`Graceful exit received...${code}`);
    client.end(false);
}

function onDisconnect(reconnect = true) {
    scheduler.stop();
    if (reconnect) {
        client.reconnect();
    }
}

client.on('connect', onDeviceConnect);
client.on("disconnect", onDisconnect);
client.on("error", onDisconnect);
client.on("close", onDisconnect.bind(this, false));
client.on('message', onDeviceMessage);
process.once('SIGTERM', onGracefulExit);