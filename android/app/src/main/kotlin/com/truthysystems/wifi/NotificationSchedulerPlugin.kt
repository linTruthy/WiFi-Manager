package com.truthysystems.wifi

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger

class NotificationSchedulerPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.truthysystems.wifi/notification_scheduler")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scheduleExactNotification" -> {
                try {
                    val timeInMillis = call.argument<Long>("timeInMillis") 
                        ?: return result.error("INVALID_ARG", "Time in millis required", null)
                    val customerId = call.argument<Int>("customerId") 
                        ?: return result.error("INVALID_ARG", "Customer ID required", null)
                    
                    NotificationScheduler.scheduleExactNotification(context, timeInMillis)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SCHEDULE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}