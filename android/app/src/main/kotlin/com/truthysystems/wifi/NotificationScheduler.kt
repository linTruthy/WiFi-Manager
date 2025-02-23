package com.truthysystems.wifi

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.truthysystems.wifi.R
import java.util.Calendar

class NotificationScheduler {
    companion object {
        fun scheduleExactNotification(context: Context, timeInMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NotificationReceiver::class.java).apply {
                action = "com.truthysystems.wifi.SCHEDULE_NOTIFICATIONS"
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { // Android 12+ (API 31+)
                // Check if we have SCHEDULE_EXACT_ALARM permission
                val hasExactAlarmPermission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.SCHEDULE_EXACT_ALARM
                ) == PackageManager.PERMISSION_GRANTED

                if (hasExactAlarmPermission) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent
                    )
                } else {
                    showExactAlarmPrompt(context)
                    // Fallback to inexact alarm
                    alarmManager.setInexactRepeating(
                        AlarmManager.RTC_WAKEUP, timeInMillis, AlarmManager.INTERVAL_DAY, pendingIntent
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) { // Android 6.0-11 (API 23-30)
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent
                )
            } else { // Android < 6.0
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
            }
        }

        private fun showExactAlarmPrompt(context: Context) {
            android.util.Log.w("NotificationScheduler", "Exact alarms permission required for timely reminders")
            NotificationManagerCompat.from(context).notify(
                1,
                android.app.Notification.Builder(context, "subscription_notifications")
                    .setContentTitle("Permission Required")
                    .setContentText("Allow exact alarms for timely subscription reminders?")
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .build()
            )
        }
    }
}

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.truthysystems.wifi.SCHEDULE_NOTIFICATIONS") {
            // Trigger native notification scheduling logic here
            scheduleNotifications(context)
        }
    }

    private fun scheduleNotifications(context: Context) {
        // This is a placeholder for native scheduling logic
        // You would typically query your database (e.g., Isar via Flutter) or use a service
        // For now, we'll log and simulate scheduling
        android.util.Log.d("NotificationReceiver", "Scheduling all notifications")
        // Example: Schedule a test notification in 5 minutes
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.MINUTE, 5)
        NotificationScheduler.scheduleExactNotification(context, calendar.timeInMillis)
    }
}