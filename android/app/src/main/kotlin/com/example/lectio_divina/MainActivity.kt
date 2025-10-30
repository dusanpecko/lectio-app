package com.example.lectio_divina

import io.flutter.embedding.android.FlutterActivity
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.content.Intent

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "sk.lectio.divina/do_not_disturb"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDndPermissions" -> {
                    result.success(checkDndPermissions())
                }
                "requestDndPermissions" -> {
                    result.success(requestDndPermissions())
                }
                "activateAndroidDnd" -> {
                    result.success(activateAndroidDnd())
                }
                "deactivateAndroidDnd" -> {
                    result.success(deactivateAndroidDnd())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun checkDndPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true // DND permissions not needed for API < 23
        }
    }
    
    private fun requestDndPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!notificationManager.isNotificationPolicyAccessGranted) {
                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                startActivity(intent)
                false
            } else {
                true
            }
        } else {
            true
        }
    }
    
    private fun activateAndroidDnd(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    val policy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        NotificationManager.Policy(
                            NotificationManager.Policy.PRIORITY_CATEGORY_CALLS or
                            NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS or
                            NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS,
                            NotificationManager.Policy.PRIORITY_SENDERS_STARRED,
                            NotificationManager.Policy.PRIORITY_SENDERS_STARRED
                        )
                    } else {
                        NotificationManager.Policy(
                            NotificationManager.Policy.PRIORITY_CATEGORY_CALLS or
                            NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS or
                            NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS,
                            NotificationManager.Policy.PRIORITY_SENDERS_STARRED,
                            NotificationManager.Policy.PRIORITY_SENDERS_STARRED
                        )
                    }
                    notificationManager.setNotificationPolicy(policy)
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        } else {
            false
        }
    }
    
    private fun deactivateAndroidDnd(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    true
                } else {
                    false
                }
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        } else {
            false
        }
    }
}
