package com.truthysystems.wifi

import android.content.ContentResolver
import android.content.Context
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import org.json.JSONObject
import java.util.*

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.truthysystems.wifi/subscription_widget"
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // First method channel for wifi functionality
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "truthy.systems/wifi")
            .setMethodCallHandler { call, result ->
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

        // Second method channel for subscription widget
         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSubscriptionWidget" -> {
                    try {
                        // Extract the data from the method call
                        val arguments = call.arguments as Map<*, *>
                        val expiringCustomers = (arguments["expiringCustomers"] as List<*>).map { customer ->
                            val customerMap = customer as Map<*, *>
                            JSONObject().apply {
                                put("name", customerMap["name"])
                                put("daysLeft", customerMap["daysLeft"])
                            }
                        }
                        val activeCustomersCount = arguments["activeCustomersCount"] as Int

                        // Update the widget using the companion object method
                        SubscriptionWidgetProvider.updateData(
                            context = this,
                            newExpiringCustomers = expiringCustomers,
                            newActiveCount = activeCustomersCount
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
    }
    private fun resourceToUriString(context: Context, resId: Int): String? {
        return (ContentResolver.SCHEME_ANDROID_RESOURCE + "://"
                + context.resources.getResourcePackageName(resId)
                + "/"
                + context.resources.getResourceTypeName(resId)
                + "/"
                + context.resources.getResourceEntryName(resId))
    }
}