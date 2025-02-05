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
import android.util.Log
import com.truthysystems.wifi.R

class SubscriptionWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "SubscriptionWidgetProvider"
        private var expiringCustomers = listOf<JSONObject>()
        private var activeCustomersCount = 0

        fun updateData(context: Context, newExpiringCustomers: List<JSONObject>, newActiveCount: Int) {
            try {
                expiringCustomers = newExpiringCustomers
                activeCustomersCount = newActiveCount
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, SubscriptionWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                
                // Ensure we have valid widget IDs
                if (appWidgetIds.isNotEmpty()) {
                    onUpdateWidgets(context, appWidgetManager, appWidgetIds)
                } else {
                    Log.w(TAG, "No active widget IDs found")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget data", e)
            }
        }

        private fun onUpdateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.subscription_widget_layout)
                
                // Setup click intent
                setupWidgetClick(context, views)
                
                // Update widget content
                updateCustomerCounts(views)
                updateExpiringCustomersList(context, views)
                
                // Update the widget
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating individual app widget", e)
            }
        }

        private fun setupWidgetClick(context: Context, views: RemoteViews) {
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                intent, 
                pendingIntentFlags
            )
            
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
            views.removeAllViews(R.id.expiring_customers_container)
            
            if (expiringCustomers.isEmpty()) {
                // Add a placeholder view if no expiring customers
                val placeholderView = RemoteViews(
                    context.packageName,
                    R.layout.subscription_list_item
                )
                placeholderView.setTextViewText(
                    R.id.customer_name,
                    "No expiring subscriptions"
                )
                views.addView(R.id.expiring_customers_container, placeholderView)
            } else {
                // Add expiring customers
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
                        "${customer.getString("daysLeft")}"
                        //"Expires in ${customer.getInt("daysLeft")} days"
                    )
                    views.addView(R.id.expiring_customers_container, itemView)
                }
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Initial update when widget is placed
        onUpdateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle any specific intents if needed
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, SubscriptionWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                
                if (appWidgetIds.isNotEmpty()) {
                    onUpdateWidgets(context, appWidgetManager, appWidgetIds)
                }
            }
        }
    }
}