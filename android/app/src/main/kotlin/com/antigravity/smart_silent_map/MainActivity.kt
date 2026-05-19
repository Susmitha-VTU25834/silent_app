package com.antigravity.smart_silent_map

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.antigravity.smart_silent_map/silent_mode"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSilentMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val success = setSilentMode(enabled)
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Notification Policy Access denied", null)
                    }
                }
                "checkDndPermission" -> {
                    result.success(isNotificationPolicyAccessGranted())
                }
                "openDndSettings" -> {
                    openNotificationPolicyAccessSettings()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setSilentMode(enabled: Boolean): Boolean {
        if (!isNotificationPolicyAccessGranted()) {
            return false
        }

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (enabled) {
            // Set to Silent/Vibrate
            audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        } else {
            // Set to Normal
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
        }
        return true
    }

    private fun isNotificationPolicyAccessGranted(): Boolean {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true
        }
    }

    private fun openNotificationPolicyAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            startActivity(intent)
        }
    }
}
