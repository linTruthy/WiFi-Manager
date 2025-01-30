import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/timezone.dart' as tz;

import '../database/models/customer.dart';

class SubscriptionNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'subscription_notifications';
  static const String channelName = 'Subscription Notifications';
  static const String channelDescription =
      'Notifications for expiring subscriptions';

  static Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        // Handle notification tap
        if (details.payload != null) {
          // Navigate to customer details page
          // Implementation depends on your navigation setup
        }
      },
    );
  }

  static Future<void> scheduleExpirationNotification(Customer customer) async {
    final daysUntilExpiry =
        customer.subscriptionEnd.difference(DateTime.now()).inDays;

    if (daysUntilExpiry <= 3 && daysUntilExpiry > 0) {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Schedule notification for different intervals
      if (daysUntilExpiry == 3) {
        await _scheduleNotification(
          customer,
          'Subscription Expiring Soon',
          '${customer.name}\'s subscription expires in 3 days',
          notificationDetails,
        );
      } else if (daysUntilExpiry == 1) {
        await _scheduleNotification(
          customer,
          'Subscription Expires Tomorrow',
          '${customer.name}\'s subscription expires tomorrow',
          notificationDetails,
        );
      }
    }
  }

  static Future<void> _scheduleNotification(
    Customer customer,
    String title,
    String body,
    NotificationDetails details,
  ) async {
    await _notifications.zonedSchedule(
      customer.id.hashCode,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: customer.id.toString(),
    );
  }
}
