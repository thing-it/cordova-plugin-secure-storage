package com.crypho.plugins;

import java.util.Set;
import java.util.HashSet;
import java.util.Iterator;

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

    Map<String, ?> fetchAll (){
        return prefs.getAll();
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
