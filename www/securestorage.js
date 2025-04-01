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
            throw new Error('[SecureStorage] Set failed: Value must be a string');
        }

        try {
            return await promisedExecution('set', key, value);
        } catch (err) {
            throw enrichError(`[SecureStorage] Set failed for key "${key}"`, err);
        }
    }

    async remove(key) {
        if (typeof key !== 'string') {
            throw new Error('[SecureStorage] Remove failed: Key must be a string');
        }

        try {
            return await promisedExecution('remove', key);
        } catch (err) {
            throw enrichError(`[SecureStorage] Remove failed for key "${key}"`, err);
        }
    }

    async clear() {
        try {
            return await promisedExecution('clear');
        } catch (err) {
            throw enrichError(`[SecureStorage] Clear failed`, err);
        }
    }

    subscribeForEvent(eventName, callbackSuccess, callbackError) {
        exec(callbackSuccess, callbackError, PLUGIN_NAME, "subscribe", [eventName]);
    }
}

function enrichError(messagePrefix, err) {
    let finalMessage = messagePrefix;
    let structuredError = {
        originalError: err,
        status: undefined,
        account: undefined,
        service: undefined,
        description: undefined,
    };

    if (typeof err === 'object') {
        structuredError = {
            ...structuredError,
            ...err
        };
        const parts = [
            err.message || null,
            err.description || null,
            err.account ? `account: ${err.account}` : null,
            err.service ? `service: ${err.service}` : null,
            err.status !== undefined ? `status: ${err.status}` : null
        ].filter(Boolean);
        if (parts.length > 0) {
            finalMessage += ` - ${parts.join(' | ')}`;
        }
    } else {
        finalMessage += ` - ${String(err)}`;
    }

    const enrichedError = new Error(finalMessage);
    Object.assign(enrichedError, structuredError);
    return enrichedError;
}

async function promisedExecution(method, ...commandArgs) {
    return new Promise((resolve, reject) =>
        exec(resolve, reject, PLUGIN_NAME, method, commandArgs)
    );
}

module.exports = new SecureStorage();
