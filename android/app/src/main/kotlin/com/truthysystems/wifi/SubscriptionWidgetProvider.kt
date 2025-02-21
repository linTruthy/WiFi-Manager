package com.truthysystems.wifi

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.content.ComponentName
import android.util.Log
import com.truthysystems.wifi.R
import java.text.SimpleDateFormat
import java.util.Date

class SubscriptionWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "SubscriptionWidgetProvider"
        private var expiringCustomers = listOf<JSONObject>()
        private var activeCustomersCount = 0
        private var totalRevenue = 0.0
        private var lastUpdated = ""

      fun updateData(context: Context, newExpiringCustomers: List<JSONObject>, newActiveCount: Int, newRevenue: Double) {
    Log.d(TAG, "Updating widget with: active=$newActiveCount, expiring=${newExpiringCustomers.size}, revenue=$newRevenue")
    expiringCustomers = newExpiringCustomers
    activeCustomersCount = newActiveCount
    totalRevenue = newRevenue
    lastUpdated = SimpleDateFormat("hh:mm a").format(Date())
    val appWidgetManager = AppWidgetManager.getInstance(context)
    val componentName = ComponentName(context, SubscriptionWidgetProvider::class.java)
    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
    if (appWidgetIds.isNotEmpty()) {
        onUpdateWidgets(context, appWidgetManager, appWidgetIds)
    } else {
        Log.w(TAG, "No active widget IDs found")
    }
}

      private fun onUpdateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }
    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.expiring_customers_container)
}

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.subscription_widget_layout)
            setupWidgetClick(context, views)
            updateStats(views)
            updateExpiringCustomersList(context, views)
            setupActionButtons(context, views)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun setupWidgetClick(context: Context, views: RemoteViews) {
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)
            views.setOnClickPendingIntent(R.id.widget_layout_root, pendingIntent)
        }

        private fun updateStats(views: RemoteViews) {
            views.setTextViewText(R.id.active_customers_text, "Active: $activeCustomersCount")
            val expiringToday = expiringCustomers.count { it.getString("daysLeft").contains("today", true) }
            val expiringSoon = expiringCustomers.size - expiringToday
            views.setTextViewText(R.id.expiring_count_text, "Today: $expiringToday | Soon: $expiringSoon")
            views.setTextViewText(R.id.revenue_text, "Revenue: UGX ${totalRevenue.toInt()}")
            views.setTextViewText(R.id.last_updated_text, "Updated: $lastUpdated")
        }

        private fun updateExpiringCustomersList(context: Context, views: RemoteViews) {
            views.removeAllViews(R.id.expiring_customers_container)
            if (expiringCustomers.isEmpty()) {
                val placeholderView = RemoteViews(context.packageName, R.layout.subscription_list_item)
                placeholderView.setTextViewText(R.id.customer_name, "No expiring subscriptions")
                views.addView(R.id.expiring_customers_container, placeholderView)
            } else {
                expiringCustomers.take(3).forEach { customer ->
                    val itemView = RemoteViews(context.packageName, R.layout.subscription_list_item)
                    itemView.setTextViewText(R.id.customer_name, customer.getString("name"))
                    val daysLeft = customer.getString("daysLeft")
                    itemView.setTextViewText(R.id.days_left, daysLeft)
                    itemView.setTextColor(R.id.days_left, if (daysLeft.contains("today", true)) 0xFFFF0000.toInt() else 0xFFFFA500.toInt())
                    val intent = Intent(context, MainActivity::class.java).apply {
                        putExtra("customerId", customer.getString("id"))
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context, customer.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    itemView.setOnClickPendingIntent(R.id.customer_name, pendingIntent)
                    views.addView(R.id.expiring_customers_container, itemView)
                }
            }
        }

        private fun setupActionButtons(context: Context, views: RemoteViews) {
            val addIntent = Intent(context, MainActivity::class.java).apply {
                putExtra("route", "/add-payment")
            }
            val addPendingIntent = PendingIntent.getActivity(
                context, 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_payment_button, addPendingIntent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        onUpdateWidgets(context, appWidgetManager, appWidgetIds)
    }
}