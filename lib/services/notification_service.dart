// services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initializationSettings);
  }

  static Future<void> schedulePaymentReminder({
    required int customerId,
    required String customerName,
    required DateTime dueDate,
    required double amount,
  }) async {
    final id = customerId.hashCode;

    final androidDetails = AndroidNotificationDetails(
      'payment_reminders',
      'Payment Reminders',
      channelDescription: 'Notifications for upcoming payment due dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    // Schedule notification for 1 day before due date
    await _notifications.zonedSchedule(
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      id,
      'Payment Due Tomorrow',
      'Reminder: $customerName\'s payment of \$${amount.toStringAsFixed(2)} is due tomorrow',
      tz.TZDateTime.from(dueDate, tz.local).subtract(const Duration(days: 1)),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
