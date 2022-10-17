const exec = require("cordova/exec");
const PLUGIN_NAME = "SecureStorage";

class SecureStorage {
    async getStartupTimestamp() {
        return promisedExecution('getStartupTimestamp');
    }
    async isDevicePasscodeSet() {
        return promisedExecution('isDevicePasscodeSet');
    }

    async getAll() {
        return promisedExecution('getAll');
    }

    async set(key, value, encrypted = true) {
        if (typeof key !== 'string' || typeof value !== 'string') {
            throw new Error('Value must be a string');
        }

        return promisedExecution('set', key, value);
    }

    async remove(key) {
        if (typeof key !== 'string') {
            throw new Error('Key must be a string');
        }
        return promisedExecution('remove', key);
    }

    async clear() {
        return promisedExecution('clear');
    }

    subscribeForEvent(eventName, callbackSuccess, callbackError) {
        exec(callbackSuccess, callbackError, PLUGIN_NAME, "subscribe", [eventName]);
    }
}

async function promisedExecution(method, ...commandArgs) {
    return new Promise((resolve, reject) => exec(resolve, reject, PLUGIN_NAME, method, commandArgs))
}

module.exports = new SecureStorage();
