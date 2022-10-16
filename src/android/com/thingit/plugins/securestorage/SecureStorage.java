package com.thingit.plugins.securestorage;

import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Base64;
import android.util.Log;
import org.apache.cordova.*;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class SecureStorage extends CordovaPlugin {
    private static final String TAG = "SecureStorage";
    private final static String SERVICE_NAME = "thing-it Mobile";
    private static final boolean SUPPORTED = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;
    private static final boolean MATCHES_ANDROID_API_28 = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P;

    private Context context;
    private String serviceAlias;

    private SharedPreferencesHandler storage;

    private final Map<String, CallbackContext> subscribers = new HashMap<>();

    private boolean initialized = false;
    private String initializationError;

    @Override
    protected void pluginInitialize() {
        try {
            if (!SUPPORTED) {
                throw new Error("API 21 (Android 5.0 Lollipop) is required. This device is running API " + Build.VERSION.SDK_INT);
            }

            context = cordova.getActivity().getApplicationContext();

            serviceAlias = context.getPackageName() + "." + SERVICE_NAME;

            storage = new SharedPreferencesHandler(serviceAlias, context);

            if (!isDeviceSecure()) {
                throw new Error("Device is not secure");
            }

            unlockCredentials();

            initialized = true;
        } catch (Exception e) {
            Log.e(TAG, "Init failed :", e);
            initializationError = e.getMessage();
        }
    }

    @Override
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext) throws JSONException {
        try {
            if ("isDevicePasscodeSet".equals(action)) {
                final boolean isSecure = isDeviceSecure();
                callbackContext.success(isSecure ? 1 : 0);
                return true;
            }
            if ("set".equals(action)) {
                final String key = args.getString(0);
                final String value = args.getString(1);

                JSONObject result = AES.encrypt(value.getBytes(), SERVICE_NAME.getBytes());
                byte[] aes_key = Base64.decode(result.getString("key"), Base64.DEFAULT);
                byte[] aes_key_enc = RSA.encrypt(aes_key, serviceAlias);
                result.put("key", Base64.encodeToString(aes_key_enc, Base64.DEFAULT));
                storage.store(key, result.toString());
                callbackContext.success();
                return true;
            }
            if ("getAll".equals(action)) {
                Map<String, String> store = storage.fetchAll();
                JSONObject storedJson = new JSONObject(store);

                Iterator<String> keys = storedJson.keys();
                while (keys.hasNext()) {
                    String key = keys.next();
                    String value = storedJson.getString(key);

                    JSONObject json = new JSONObject(value);
                    final byte[] encKey = Base64.decode(json.getString("key"), Base64.DEFAULT);
                    JSONObject data = json.getJSONObject("value");
                    final byte[] ct = Base64.decode(data.getString("ct"), Base64.DEFAULT);
                    final byte[] iv = Base64.decode(data.getString("iv"), Base64.DEFAULT);
                    final byte[] adata = Base64.decode(data.getString("adata"), Base64.DEFAULT);
                    byte[] decryptedKey = RSA.decrypt(encKey, serviceAlias);
                    String decrypted = AES.decrypt(ct, decryptedKey, iv, adata);
                    storedJson.put(key, decrypted);
                }

                callbackContext.success(storedJson.toString());

                return true;
            }
            if ("remove".equals(action)) {
                String key = args.getString(0);
                storage.remove(key);
                callbackContext.success();
                return true;
            }
            if ("clear".equals(action)) {
                storage.clear();
                callbackContext.success();
                return true;
            }
            if ("subscribe".equals(action)) {
                subscribeForEvent(args, callbackContext);
                return true;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error during command execution:", e);
            callbackContext.error(e.getMessage());
            return true;
        }

        return false;
    }

    private void subscribeForEvent(CordovaArgs arguments, CallbackContext callbackContext) throws JSONException {
        final String eventName = arguments.getString(0);
        subscribers.put(eventName, callbackContext);

        if ("initialized".equals(eventName)) {
            publishEvent(eventName);
        }
    }

    private void publishEvent(String eventName) {
        CallbackContext subscriber = subscribers.get(eventName);
        if (subscriber == null) return;

        if ("initialized".equals(eventName)) {
            if (initialized) {
                subscriber.success();
                return;
            }
            if (initializationError != null) {
                subscriber.error(initializationError);
            }
        } else {
            subscriber.success();
        }
    }

    public String getInitializationError() {
        return initializationError;
    }

    private boolean isDeviceSecure() {
        KeyguardManager keyguardManager = (KeyguardManager) (context.getSystemService(Context.KEYGUARD_SERVICE));
        try {
            Method isSecure = null;
            isSecure = keyguardManager.getClass().getMethod("isDeviceSecure");
            return (Boolean) isSecure.invoke(keyguardManager);
        } catch (Exception e) {
            return keyguardManager.isKeyguardSecure();
        }
    }

    private void unlockCredentials() throws Exception {
        if (!MATCHES_ANDROID_API_28) {
            if (RSA.isEntryAvailable(serviceAlias)) return;

            Intent intent = new Intent("com.android.credentials.UNLOCK");
            startActivity(intent);
            return;
        }

        if (!RSA.isEntryAvailable(serviceAlias)) {
            generateEncryptionKeys();
            return;
        }
        if (RSA.userAuthenticationRequired(serviceAlias)) {
            KeyguardManager keyguardManager = (KeyguardManager) (context.getSystemService(Context.KEYGUARD_SERVICE));
            Intent intent = keyguardManager.createConfirmDeviceCredentialIntent(null, null);
            startActivity(intent);
        }
    }

    private void generateEncryptionKeys() throws Exception {
        storage.clear();
        RSA.createKeyPair(context, serviceAlias);
    }

    private void startActivity(Intent intent) {
        cordova.getActivity().startActivity(intent);
    }
}
