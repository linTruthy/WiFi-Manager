package com.truthysystems.wifi

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NotificationSchedulerPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.truthysystems.wifi/notification_scheduler")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "scheduleExactNotification" -> {
        val timeInMillis = call.argument<Long>("timeInMillis") ?: return result.error("INVALID_ARG", "Time in millis required", null)
        val customerId = call.argument<Int>("customerId") ?: return result.error("INVALID_ARG", "Customer ID required", null)
        NotificationScheduler.scheduleExactNotification(call.arguments as Context, timeInMillis)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}