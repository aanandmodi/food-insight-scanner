package com.food_insight_scanner.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.util.Log

class MainActivity: FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            Log.d("MainActivity", "Manually registering plugins to fix channel-error!")
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            Log.e("MainActivity", "Plugin registration failed", e)
        }
    }
}