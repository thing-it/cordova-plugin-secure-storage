package com.thingit.plugins.securestorage;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.HashMap;
import java.util.Map;

public class SharedPreferencesHandler {
    private final SharedPreferences prefs;

    public SharedPreferencesHandler(String prefsName, Context ctx) {
        prefs = ctx.getSharedPreferences(prefsName + "_SS", 0);
    }

    void store(String key, String value) {
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("_SS_" + key, value);
        editor.commit();
    }

    Map<String, String> fetchAll() {
        Map<String, String> store = (Map<String, String>) prefs.getAll();
        Map<String, String> convertedStore = new HashMap<>();
        for (Map.Entry<String, String> entry : store.entrySet()) {
            convertedStore.put(entry.getKey().substring(4), entry.getValue());
        }
        return convertedStore;
    }

    void remove(String key) {
        SharedPreferences.Editor editor = prefs.edit();
        editor.remove("_SS_" + key);
        editor.commit();
    }

    void clear() {
        SharedPreferences.Editor editor = prefs.edit();
        editor.clear();
        editor.commit();
    }
}
