package com.example.bank_mobile_security_test

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Debug
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bank.app/device_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAndroidSecurityReport") {
                try {
                    val report = mapOf(
                        "isDevOptionsEnabled" to isDevOptionsEnabled(),
                        "isAdbEnabled" to isAdbEnabled(),
                        "isBootloaderUnlocked" to isBootloaderUnlocked(),
                        "isEmulator" to isEmulator(),
                        "isDebuggerAttached" to isDebuggerAttached()
                    )
                    result.success(report)
                } catch (e: Exception) {
                    result.error("SECURITY_CHECK_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isDevOptionsEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0
            ) != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun isAdbEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.ADB_ENABLED, 0
            ) != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun isBootloaderUnlocked(): Boolean {
        return try {
            val p = Runtime.getRuntime().exec("getprop ro.boot.verifiedbootstate")
            val reader = BufferedReader(InputStreamReader(p.inputStream))
            val state = reader.readLine()?.trim()?.lowercase() ?: ""
            if (state == "orange" || state == "yellow" || state == "red") {
                return true
            }

            val pFlash = Runtime.getRuntime().exec("getprop ro.boot.flash.locked")
            val flashLocked = BufferedReader(InputStreamReader(pFlash.inputStream)).readLine()?.trim() ?: "1"
            flashLocked == "0"
        } catch (e: Exception) {
            false
        }
    }

    private fun isEmulator(): Boolean {
        return try {
            val isGeneric = Build.FINGERPRINT.startsWith("generic")
                    || Build.FINGERPRINT.startsWith("unknown")
                    || Build.MODEL.contains("google_sdk")
                    || Build.MODEL.contains("Emulator")
                    || Build.MODEL.contains("Android SDK built for x86")
                    || Build.MANUFACTURER.contains("Genymotion")
                    || Build.HARDWARE.contains("goldfish")
                    || Build.HARDWARE.contains("ranchu")
                    || Build.PRODUCT.contains("sdk_google")
                    || Build.PRODUCT.contains("google_sdk")
                    || Build.PRODUCT.contains("vbox86p")

            val sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val hasAccelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

            isGeneric || !hasAccelerometer
        } catch (e: Exception) {
            false
        }
    }

    private fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }
}
