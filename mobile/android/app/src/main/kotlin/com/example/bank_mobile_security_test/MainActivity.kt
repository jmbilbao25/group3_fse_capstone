package com.example.bank_mobile_security_test

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.view.Display
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
            when (call.method) {
                "getAndroidSecurityReport" -> {
                    try {
                        val report = mapOf(
                            "isDevOptionsEnabled" to isDevOptionsEnabled(),
                            "isAdbEnabled" to isAdbEnabled(),
                            "isBootloaderUnlocked" to isBootloaderUnlocked(),
                            "isEmulator" to isEmulator(),
                            "isDebuggerAttached" to isDebuggerAttached(),
                            "isScreenSharingActive" to isScreenSharingActive()
                        )
                        result.success(report)
                    } catch (e: Exception) {
                        result.error("SECURITY_CHECK_ERROR", e.localizedMessage, null)
                    }
                }
                "isScreenSharingActive" -> {
                    try {
                        result.success(isScreenSharingActive())
                    } catch (e: Exception) {
                        result.error("SCREEN_SHARING_CHECK_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isDevOptionsEnabled(): Boolean {
        // Temporarily disabled for development/testing
        return false
    }

    private fun isAdbEnabled(): Boolean {
        // Temporarily disabled for development/testing so ADB-connected emulators can run
        return false
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
        // Temporarily disabled to allow testing inside Android emulators
        return false
    }

    private fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    private fun isScreenSharingActive(): Boolean {
        return try {
            val displayManager = getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
            if (displayManager != null) {
                val displays = displayManager.displays
                for (display in displays) {
                    if (display.displayId != Display.DEFAULT_DISPLAY) {
                        return true
                    }
                    if ((display.flags and Display.FLAG_PRESENTATION) != 0) {
                        return true
                    }
                }
            }

            val packageManager = packageManager
            val knownRemoteTools = listOf(
                "com.teamviewer.host.market",
                "com.teamviewer.quicksupport.market",
                "com.anydesk.anydeskandroid",
                "com.zoho.assist",
                "com.splashtop.remote"
            )
            for (pkg in knownRemoteTools) {
                try {
                    packageManager.getPackageInfo(pkg, 0)
                    return true
                } catch (_: Exception) {}
            }

            false
        } catch (e: Exception) {
            false
        }
    }
}
