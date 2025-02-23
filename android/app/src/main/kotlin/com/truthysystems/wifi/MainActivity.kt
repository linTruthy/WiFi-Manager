package com.truthysystems.wifi

import android.content.ContentResolver
import android.content.Context
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import org.json.JSONObject
import io.flutter.embedding.engine.plugins.FlutterPlugin // Required for plugin interface

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.truthysystems.wifi/subscription_widget"
    private lateinit var subscriptionChannel: MethodChannel
    private lateinit var utilityChannel: MethodChannel
    private lateinit var notificationSchedulerChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register utility channel
        utilityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "truthy.systems/wifi")
        utilityChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "drawableToUri" -> {
                    val resourceId = this@MainActivity.resources.getIdentifier(
                        call.arguments as String,
                        "drawable",
                        this@MainActivity.packageName
                    )
                    result.success(resourceToUriString(this@MainActivity.applicationContext, resourceId))
                }
                "getAlarmUri" -> {
                    result.success(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM).toString())
                }
                else -> result.notImplemented()
            }
        }

        // Register subscription widget channel
        subscriptionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        subscriptionChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSubscriptionWidget" -> {
                    try {
                        val arguments = call.arguments as Map<*, *>
                        val expiringCustomers = (arguments["expiringCustomers"] as List<*>).map { customer ->
                            val customerMap = customer as Map<*, *>
                            JSONObject().apply {
                                put("name", customerMap["name"])
                                put("daysLeft", customerMap["daysLeft"])
                                put("id", customerMap["id"])
                            }
                        }
                        val activeCustomersCount = arguments["activeCustomersCount"] as Int
                        val newRevenue = (arguments["totalRevenue"] as? Double) ?: 0.0
                        SubscriptionWidgetProvider.updateData(
                            context = this,
                            newExpiringCustomers = expiringCustomers,
                            newActiveCount = activeCustomersCount,
                            newRevenue = newRevenue
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register NotificationSchedulerPlugin directly with FlutterEngine
        val notificationSchedulerPlugin = NotificationSchedulerPlugin()
        flutterEngine.plugins.add(notificationSchedulerPlugin) // Add plugin to engine

        // Optionally, set up the MethodChannel explicitly if needed (not strictly required)
        notificationSchedulerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.truthysystems.wifi/notification_scheduler")
        notificationSchedulerChannel.setMethodCallHandler(notificationSchedulerPlugin)
    }

    private fun resourceToUriString(context: Context, resId: Int): String? {
        return (ContentResolver.SCHEME_ANDROID_RESOURCE + "://" +
                context.resources.getResourcePackageName(resId) + "/" +
                context.resources.getResourceTypeName(resId) + "/" +
                context.resources.getResourceEntryName(resId))
    }

    override fun onDestroy() {
        super.onDestroy()
        subscriptionChannel.setMethodCallHandler(null)
        utilityChannel.setMethodCallHandler(null)
        notificationSchedulerChannel.setMethodCallHandler(null)
    }
}