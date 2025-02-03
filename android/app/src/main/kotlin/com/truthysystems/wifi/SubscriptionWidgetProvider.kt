package com.truthysystems.wifi

import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.content.ComponentName
import android.view.View
import com.truthysystems.wifi.R

class SubscriptionWidgetProvider : AppWidgetProvider() {
    companion object {
        private var expiringCustomers = listOf<JSONObject>()
        private var activeCustomersCount = 0

        fun updateData(context: Context, newExpiringCustomers: List<JSONObject>, newActiveCount: Int) {
            expiringCustomers = newExpiringCustomers
            activeCustomersCount = newActiveCount
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SubscriptionWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Update all widgets
            val instance = SubscriptionWidgetProvider()
            instance.onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        try {
            val views = RemoteViews(context.packageName, R.layout.subscription_widget_layout)
            
            setupWidgetClick(context, views)
            updateCustomerCounts(views)
            updateExpiringCustomersList(context, views)

            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setupWidgetClick(context: Context, views: RemoteViews) {
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)
        views.setOnClickPendingIntent(R.id.widget_layout_root, pendingIntent)
    }

    private fun updateCustomerCounts(views: RemoteViews) {
        views.setTextViewText(
            R.id.active_customers_text, 
            "Active Customers: $activeCustomersCount"
        )
        
        val expiringCount = expiringCustomers.size
        views.setTextViewText(
            R.id.expiring_count_text, 
            "Expiring Soon: $expiringCount"
        )
    }

    private fun updateExpiringCustomersList(context: Context, views: RemoteViews) {
        if (expiringCustomers.isNotEmpty()) {
            views.removeAllViews(R.id.expiring_customers_container)
            expiringCustomers.forEach { customer ->
                val itemView = RemoteViews(
                    context.packageName, 
                    R.layout.subscription_list_item
                )
                itemView.setTextViewText(
                    R.id.customer_name, 
                    customer.getString("name")
                )
                itemView.setTextViewText(
                    R.id.days_left, 
                    "Expires in ${customer.getInt("daysLeft")} days"
                )
                views.addView(R.id.expiring_customers_container, itemView)
            }
        }
    }
}