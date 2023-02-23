const { debuglog } = require('util');
const { spawn } = require("child_process");

const debug = debuglog("smart-matrix-server:post-process:tidbyt");

const { APPLET_FOLDER = '/applets' } = process.env;

module.exports = async function onAppletRender(applet) {
    const { name, tidbyts = [] } = applet;

    for (let i = 0; i < tidbyts.length; i++) {
        const deviceId = tidbyts[i].deviceId;
        const apiToken = tidbyts[i].apiToken;
        const installationId = tidbyts[i].installationId;
        const background = !!tidbyts[i].background;

        const pushArgs = [
            'push',
            deviceId,
            `${APPLET_FOLDER}/${name}/${name}.webp`
        ];
        let outputError = '';

        if (apiToken) {
            pushArgs.push('--api-token');
            pushArgs.push(apiToken);
        }

        if (installationId) {
            pushArgs.push('--installation-id');
            pushArgs.push(installationId);
        }

        if (background) {
            pushArgs.push('--background');
        }

        debug(`pushing ${name} to ${tidbyts[i].deviceId}${background ? ' in the background' : ''}...`);

        const pushCommand = spawn('pixlet', pushArgs);
        
        const timeout = setTimeout(() => {
            console.log(`Rendering timed out for ${name}`);
            try {
            process.kill(pushCommand.pid, 'SIGKILL');
            } catch (e) {
            console.log('Could not kill process ^', e);
            }
        }, 20000);

        pushCommand.stdout.on('data', (data) => {
            outputError += data
        })

        pushCommand.stderr.on('data', (data) => {
            outputError += data
        })
    
        pushCommand.on('close', (code) => {
            clearTimeout(timeout);
            if(code === 0) {
                debug(`pushed ${name} to ${deviceId} successfully!`);
            } else {
                console.error(outputError);
                debug("Applet failed to push.");
            }
        });
    }
};