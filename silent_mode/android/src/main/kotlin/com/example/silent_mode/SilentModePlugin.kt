package com.example.silent_mode

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SilentModePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.antigravity.smart_silent_map/silent_mode")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
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

    private fun setSilentMode(enabled: Boolean): Boolean {
        if (!isNotificationPolicyAccessGranted()) {
            return false
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (enabled) {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                } else {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                }
            } else {
                if (enabled) {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                } else {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                }
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun isNotificationPolicyAccessGranted(): Boolean {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true
        }
    }

    private fun openNotificationPolicyAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
