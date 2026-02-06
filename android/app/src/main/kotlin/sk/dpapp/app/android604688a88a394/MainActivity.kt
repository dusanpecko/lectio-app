package sk.dpapp.app.android604688a88a394

import androidx.annotation.NonNull
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.content.Intent
import android.net.Uri

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "sk.lectio.divina/do_not_disturb"
    private lateinit var notificationManager: NotificationManager

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install the splash screen before calling super.onCreate()
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkDndPermissions" -> {
                    result.success(checkDndPermissions())
                }
                "requestDndPermissions" -> {
                    requestDndPermissions()
                    result.success(true)
                }
                "activateAndroidDnd" -> {
                    val success = activateAndroidDnd(call.arguments as Map<String, Any>)
                    result.success(success)
                }
                "deactivateAndroidDnd" -> {
                    val success = deactivateAndroidDnd()
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkDndPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true // Pre Android 6.0 nie sú potrebné špeciálne povolenia
        }
    }

    private fun requestDndPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!notificationManager.isNotificationPolicyAccessGranted) {
                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }

    private fun activateAndroidDnd(arguments: Map<String, Any>): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    return false
                }

                val allowCalls = arguments["allowCalls"] as? Boolean ?: false  // Zmenil som na false
                val allowMessages = arguments["allowMessages"] as? Boolean ?: false
                val allowAlarms = arguments["allowAlarms"] as? Boolean ?: true
                val allowMedia = arguments["allowMedia"] as? Boolean ?: true
                val allowReminders = arguments["allowReminders"] as? Boolean ?: false
                val allowEvents = arguments["allowEvents"] as? Boolean ?: false

                // Vytvor priority categories podľa nastavení - prísnejšie nastavenie
                var priorityCategories = 0
                // Úplne vypneme calls a messages pre maximálny pokoj
                // if (allowCalls) priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_CALLS
                // if (allowMessages) priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_MESSAGES
                if (allowAlarms) priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS
                
                // PRIORITY_CATEGORY_MEDIA nie je dostupné v starších verziách
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && allowMedia) {
                    priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_MEDIA
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    if (allowReminders) priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_REMINDERS
                    if (allowEvents) priorityCategories = priorityCategories or NotificationManager.Policy.PRIORITY_CATEGORY_EVENTS
                }

                // Vytvor policy pre všetky verzie Android
                val policy = NotificationManager.Policy(
                    priorityCategories,
                    NotificationManager.Policy.PRIORITY_SENDERS_ANY, // Emergency calls
                    NotificationManager.Policy.PRIORITY_SENDERS_STARRED // Starred contacts for messages
                )

                // Nastav policy a aktivuj DND
                notificationManager.notificationPolicy = policy
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                
                // Debug logging
                android.util.Log.d("DND", "Android DND activated with categories: $priorityCategories")
                android.util.Log.d("DND", "Current interruption filter: ${notificationManager.currentInterruptionFilter}")
                android.util.Log.d("DND", "Policy access granted: ${notificationManager.isNotificationPolicyAccessGranted}")

                true
            } else {
                // Pre Android < 6.0 nie je DND API dostupné
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun deactivateAndroidDnd(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    true
                } else {
                    false
                }
            } else {
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}