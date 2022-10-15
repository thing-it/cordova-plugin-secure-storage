package com.crypho.plugins;

import java.util.Set;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.HashMap;

import android.content.SharedPreferences;
import android.content.Context;

public class SharedPreferencesHandler {
    private SharedPreferences prefs;

    public SharedPreferencesHandler (String prefsName, Context ctx){
        prefs = ctx.getSharedPreferences(prefsName  + "_SS", 0);
    }

    void store(String key, String value){
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("_SS_" + key, value);
        editor.commit();
    }

    Map<String, String> fetchAll (){
        Map<String, String> store = (Map<String, String>)prefs.getAll();
        Map<String, String> convertedStore = new HashMap<String, String>();
        for (Map.Entry<String, String> entry : store.entrySet()) {
            convertedStore.put(entry.getKey().substring(4), (String)entry.getValue());
        }
        return convertedStore;
    }

    void remove (String key){
        SharedPreferences.Editor editor = prefs.edit();
        editor.remove("_SS_" + key);
        editor.commit();
    }

    void clear (){
        SharedPreferences.Editor editor = prefs.edit();
        editor.clear();
        editor.commit();
    }
}
