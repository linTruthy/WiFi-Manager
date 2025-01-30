import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../database/models/customer.dart';
import '../database/models/plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String channelId = 'subscription_notifications';
  static const String channelName = 'Subscription Notifications';
  static const String channelDescription =
      'Notifications for expiring subscriptions';
  static const _scheduledNotificationsKey = 'scheduled_notifications';

  static Future<void> initialize() async {
    await _requestPermissions();
    await _initializeNotifications();
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.request();
    final platform =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await platform?.requestNotificationsPermission();
    await platform?.requestExactAlarmsPermission();
  }

  static Future<void> _initializeNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
    );

    final platform =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await platform?.createNotificationChannel(androidChannel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(initializationSettings);
    
  }

  static Future<void> scheduleExpirationNotification(Customer customer) async {
    if (await _isNotificationScheduled(customer.id)) {
      debugPrint('Notification already scheduled for ${customer.name}');
      return;
    }

    final notificationTime = _calculateNotificationTime(customer);
    if (notificationTime.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint('Notification time is in the past for ${customer.name}');
      return;
    }

    final notificationDetails = _createNotificationDetails();

    try {
      await _notifications.zonedSchedule(
        customer.id.hashCode,
        'Subscription Expiring',
        _generateMessage(customer),
        notificationTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await _markNotificationScheduled(customer.id, notificationTime);
      debugPrint('Scheduled notification for ${customer.name}');
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  static Future<bool> _isNotificationScheduled(int customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
    if (scheduledNotifications == null) return false;

    final notifications =
        json.decode(scheduledNotifications) as Map<String, dynamic>;
    final scheduledTime = notifications[customerId.toString()];

    if (scheduledTime == null) return false;

    final notificationTime = DateTime.parse(scheduledTime);
    return notificationTime.isAfter(DateTime.now());
  }

  static Future<void> _markNotificationScheduled(
    int customerId,
    tz.TZDateTime notificationTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
    final notifications =
        scheduledNotifications != null
            ? json.decode(scheduledNotifications) as Map<String, dynamic>
            : <String, dynamic>{};

    notifications[customerId.toString()] = notificationTime.toString();
    await prefs.setString(
      _scheduledNotificationsKey,
      json.encode(notifications),
    );
  }

  static Future<void> clearExpiredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
    if (scheduledNotifications == null) return;

    final notifications =
        json.decode(scheduledNotifications) as Map<String, dynamic>;
    notifications.removeWhere((_, timeStr) {
      final time = DateTime.parse(timeStr);
      return time.isBefore(DateTime.now());
    });

    await prefs.setString(
      _scheduledNotificationsKey,
      json.encode(notifications),
    );
  }

  static String _generateMessage(Customer customer) {
    final daysLeft = customer.subscriptionEnd.difference(DateTime.now()).inDays;
    return '${customer.name}\'s ${customer.planType.name} plan expires in $daysLeft days';
  }

  static tz.TZDateTime _calculateNotificationTime(Customer customer) {
    final now = tz.TZDateTime.now(tz.local);
    final end = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);

    // Notification scheduling logic based on plan type
    switch (customer.planType) {
      case PlanType.daily:
        return end.subtract(const Duration(hours: 2));
      case PlanType.weekly:
        return end.subtract(const Duration(days: 1));
      case PlanType.monthly:
        return end.subtract(const Duration(days: 3));
    }
  }

  static NotificationDetails _createNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Subscription Notifications',
        channelDescription: 'Notifications for expiring subscriptions',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
      ),
    );
  }
}

class TestNotificationWidget extends StatelessWidget {
  const TestNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Notifications')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Create a test customer
            final testCustomer = Customer(
              contact: '1234567890',
              wifiName: 'TestWiFi',
              currentPassword: 'testpassword',
              subscriptionStart: DateTime.now(),

              isActive: true,
              planType: PlanType.monthly,

              name: 'John Doe',
              subscriptionEnd: DateTime.now().add(Duration(seconds: 5)),
            );

            try {
              await SubscriptionNotificationService.scheduleExpirationNotification(
                testCustomer,
              );
              print('Notification scheduled successfully');
            } catch (e) {
              print('Failed to schedule notification: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to schedule notification: $e')),
              );
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test notification scheduled!')),
            );
          },
          child: const Text('Schedule Test Notification'),
        ),
      ),
    );
  }
}
