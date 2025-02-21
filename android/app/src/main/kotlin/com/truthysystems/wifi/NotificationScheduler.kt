package com.truthysystems.wifi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.work.WorkManager
import com.truthysystems.wifi.R
import java.util.Calendar

class NotificationScheduler {
    companion object {
        fun scheduleExactNotification(context: Context, timeInMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NotificationReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ (API 31+): Request SCHEDULE_EXACT_ALARM
                if (AlarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent
                    )
                } else {
                    // Show user prompt to request exact alarm permission
                    showExactAlarmPrompt(context)
                    // Fallback to inexact alarm
                    alarmManager.setInexactRepeating(
                        AlarmManager.RTC_WAKEUP, timeInMillis, AlarmManager.INTERVAL_DAY, pendingIntent
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Android 6.0-11 (API 23-30): Use setExactAndAllowWhileIdle
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent
                )
            } else {
                // Android < 6.0: Use setExact
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
            }
        }

        private fun showExactAlarmPrompt(context: Context) {
            // Implement a user prompt or dialog using AlertDialog
            // Example: Show a dialog explaining why exact alarms are needed
            // This is a placeholder; you'll need to implement a full dialog
            // For simplicity, we'll log and notify
            android.util.Log.w("NotificationScheduler", "Exact alarms permission required for timely reminders")
            NotificationManagerCompat.from(context).notify(
                1,
                android.app.Notification.Builder(context, "subscription_notifications")
                    .setContentTitle("Permission Required")
                    .setContentText("Allow exact alarms for timely subscription reminders?")
                    .setSmallIcon(R.drawable.ic_launcher)
                    .build()
            )
        }
    }
}

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Trigger notification scheduling here
        SubscriptionNotificationService.scheduleAllNotifications(context)
    }
}