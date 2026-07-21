package com.deliv.driver

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.deliv.driver/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stopLocationService" -> {
                        try {
                            stopGeolocatorForeground()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun stopGeolocatorForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancelAll()

        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val services = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            am.getRunningServices(100)
        } else {
            @Suppress("DEPRECATION")
            am.getRunningServices(Int.MAX_VALUE)
        }

        for (svc in services) {
            val name = svc.service.className
            if (name.contains("geolocator", ignoreCase = true) ||
                name.contains("location", ignoreCase = true) ||
                name.contains("background", ignoreCase = true)) {
                try {
                    stopService(Intent(this, Class.forName(name)))
                } catch (_: Exception) {}
            }
        }
    }
}
