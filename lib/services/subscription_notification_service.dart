import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_manager/app_router.dart';
import '../database/models/customer.dart';
import '../database/models/plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../screens/customer_detail_screen.dart';

class SubscriptionNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const String channelId = 'subscription_notifications';
  static const String channelName = 'Subscription Notifications';
  static const String channelDescription =
      'Notifications for expiring subscriptions';
  static const _scheduledNotificationsKey = 'scheduled_notifications';
  static final _logger = Logger(); // Add logging
  static Future<void> initialize() async {
    await _requestPermissions();
    await _initializeNotifications();
    _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          // Navigate to the customer details page
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _buildCustomerDetailScreen(payload),
              ),
            );
          }
        }
      },
    );
  }

  static Widget _buildCustomerDetailScreen(String customerId) {
    return FutureBuilder<Customer?>(
      future: _getCustomerById(int.parse(customerId)),
      builder: (context, snapshot) {
        return AppRouter.buildLoadingOrError(
          snapshot,
          (data) => CustomerDetailScreen(customer: data),
        );
      },
    );
  }

  static Future<Customer> _getCustomerById(int customerId) async {
    final isar = Isar.getInstance('wifi_manager');
    final customer = await isar?.customers.get(customerId);
    if (customer == null) {
      throw Exception('Customer not found');
    }
    return customer;
  }

  static Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();

    // Request exact alarm permission for Android 12+
    if (Platform.isAndroid) {
      final platform =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      // Request both notifications and exact alarms permission
      await Future.wait([
        platform?.requestNotificationsPermission() ?? Future.value(),
        platform?.requestExactAlarmsPermission() ?? Future.value(),
      ]);

      // Check if permissions were granted
      final areNotificationsGranted = await Permission.notification.isGranted;
      final hasAlarmPermission =
          await platform?.areNotificationsEnabled() ?? false;

      if (!areNotificationsGranted || !hasAlarmPermission) {
        _logger.log(
          Level.warning,
          'Required permissions not granted. Notifications may not work.',
        );
      }
    }
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
      _logger.log(
        Level.info,
        'Notification already scheduled for customer: ${customer.id}',
      );
      return;
    }

    final notificationTime = _calculateNotificationTime(customer);
    final now = tz.TZDateTime.now(tz.local);

    // If calculated time is in the past, schedule for next valid time
    if (notificationTime.isBefore(now)) {
      // For expired/nearly expired subscriptions, schedule immediate notification
      if (customer.subscriptionEnd.difference(DateTime.now()) <
          const Duration(hours: 24)) {
        _logger.log(
          Level.info,
          'Scheduling immediate notification for near-expiry customer: ${customer.id}',
        );
        await _scheduleImmediateNotification(customer);
        return;
      }

      // Log the issue
      _logger.log(
        Level.warning,
        'Calculated notification time was in the past for customer: ${customer.id}',
      );
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
        payload: customer.id.toString(),
      );

      await _saveScheduledNotification(customer, notificationTime);
      await _markNotificationScheduled(customer.id, notificationTime);

      _logger.log(
        Level.info,
        'Successfully scheduled notification for customer: ${customer.id}',
      );
    } catch (e) {
      _logger.log(
        Level.error,
        'Failed to schedule notification for customer: ${customer.id}, Error: $e',
      );
      rethrow;
    }
  }

  static Future<void> _scheduleImmediateNotification(Customer customer) async {
    final notificationDetails = _createNotificationDetails();

    try {
      await _notifications.show(
        customer.id.hashCode,
        'Subscription Expiring Soon',
        _generateMessage(customer),
        notificationDetails,
        payload: customer.id.toString(),
      );

      _logger.log(
        Level.info,
        'Successfully showed immediate notification for customer: ${customer.id}',
      );
    } catch (e) {
      _logger.log(
        Level.error,
        'Failed to show immediate notification for customer: ${customer.id}, Error: $e',
      );
    }
  }

  static Future<void> _saveScheduledNotification(
    Customer customer,
    tz.TZDateTime notificationTime,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledNotificationsString =
          prefs.getString('scheduled_notifications') ?? '{}';

      // Parse existing notifications
      final notifications =
          json.decode(scheduledNotificationsString) as Map<String, dynamic>;

      // Create a comprehensive notification object
      final notificationDetails = {
        'customerId': customer.id.toString(),
        'customerName': customer.name,
        'contact': customer.contact,
        'wifiName': customer.wifiName,
        'planType': customer.planType.toString().split('.').last,
        'subscriptionStart': customer.subscriptionStart.toIso8601String(),
        'subscriptionEnd': customer.subscriptionEnd.toIso8601String(),
        'notificationTime': notificationTime.toIso8601String(),
        'message': _generateMessage(customer),
        'status': 'scheduled',
        'isActive': customer.isActive,
      };

      // Store notification time for quick lookups
      notifications[customer.id.toString()] =
          notificationTime.toIso8601String();

      // Save the updated notifications map
      await prefs.setString(
        'scheduled_notifications',
        json.encode(notifications),
      );

      // Optionally, store the detailed notification information separately
      final detailedNotificationsString =
          prefs.getString('detailed_scheduled_notifications') ?? '{}';

      final detailedNotifications =
          json.decode(detailedNotificationsString) as Map<String, dynamic>;

      detailedNotifications[customer.id.toString()] = notificationDetails;

      await prefs.setString(
        'detailed_scheduled_notifications',
        json.encode(detailedNotifications),
      );

      _logger.log(
        Level.info,
        'Saved notification for customer: ${customer.id}',
      );
    } catch (e) {
      _logger.log(Level.error, 'Failed to save notification: $e');
      throw NotificationStorageException('Failed to save notification: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailedNotificationsString = prefs.getString(
        'detailed_scheduled_notifications',
      );

      if (detailedNotificationsString == null) {
        _logger.log(Level.info, 'No detailed scheduled notifications found');
        return [];
      }

      final Map<String, dynamic> decoded = json.decode(
        detailedNotificationsString,
      );

      final notifications =
          decoded.values.map<Map<String, dynamic>>((notification) {
            return {
              'customerId':
                  int.tryParse(notification['customerId'].toString()) ?? 0,
              'customerName': notification['customerName'],
              'contact': notification['contact'],
              'wifiName': notification['wifiName'],
              'planType': notification['planType'],
              'subscriptionStart': DateTime.parse(
                notification['subscriptionStart'],
              ),
              'subscriptionEnd': DateTime.parse(
                notification['subscriptionEnd'],
              ),
              'notificationTime': DateTime.parse(
                notification['notificationTime'],
              ),
              'message': notification['message'],
              'status': notification['status'],
              'isActive': notification['isActive'] ?? false,
            };
          }).toList();

      _logger.log(
        Level.info,
        'Retrieved ${notifications.length} detailed scheduled notifications',
      );
      return notifications;
    } catch (e) {
      _logger.log(
        Level.error,
        'Failed to get detailed scheduled notifications: $e',
      );
      throw NotificationStorageException(
        'Failed to get detailed scheduled notifications: $e',
      );
    }
  }

  // Helper method to safely parse customer ID
  static int _parseCustomerId(dynamic id) {
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  // Helper method to safely parse DateTime
  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        _logger.log(Level.warning, 'Failed to parse date: $dateTime');
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // Helper method to safely parse PlanType
  static PlanType _parsePlanType(dynamic planType) {
    if (planType == null) return PlanType.monthly; // Default

    // If it's already a PlanType, return it
    if (planType is PlanType) return planType;

    // If it's a string, try to match
    if (planType is String) {
      return PlanType.values.firstWhere(
        (type) =>
            type.toString().split('.').last.toLowerCase() ==
            planType.toLowerCase(),
        orElse: () => PlanType.monthly, // Default if no match
      );
    }

    return PlanType.monthly; // Default
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
    final now = DateTime.now();
    final end = customer.subscriptionEnd;
    final duration = end.difference(now);

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    String timeDescription;
    if (days > 0) {
      timeDescription =
          '$days day${days != 1 ? 's' : ''}, '
          '$hours hour${hours != 1 ? 's' : ''}, '
          '$minutes minute${minutes != 1 ? 's' : ''} left';
    } else if (hours > 0) {
      timeDescription =
          '$hours hour${hours != 1 ? 's' : ''}, '
          '$minutes minute${minutes != 1 ? 's' : ''} left';
    } else {
      timeDescription = '$minutes minute${minutes != 1 ? 's' : ''} left';
    }

    return '${customer.name}\'s ${customer.planType.name} plan expires in $timeDescription';
  }

  static tz.TZDateTime _calculateNotificationTime(Customer customer) {
    final end = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);

    // Notification scheduling logic based on plan type with more precise timing
    switch (customer.planType) {
      case PlanType.daily:
        return end.subtract(const Duration(hours: 2, minutes: 30));
      case PlanType.weekly:
        return end.subtract(const Duration(days: 1, hours: 12));
      case PlanType.monthly:
        return end.subtract(const Duration(days: 3, hours: 6, minutes: 45));
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

  static Future<void> updateNotificationStatus(
    int customerId,
    String newStatus,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailedNotificationsString = prefs.getString(
        'detailed_scheduled_notifications',
      );

      if (detailedNotificationsString == null) return;

      final Map<String, dynamic> notifications = json.decode(
        detailedNotificationsString,
      );

      if (notifications.containsKey(customerId.toString())) {
        notifications[customerId.toString()]['status'] = newStatus;

        await prefs.setString(
          'detailed_scheduled_notifications',
          json.encode(notifications),
        );

        _logger.log(
          Level.info,
          'Updated notification status for customer: $customerId',
        );
      }
    } catch (e) {
      _logger.log(Level.error, 'Failed to update notification status: $e');
    }
  }
}

// class TestNotificationWidget extends StatelessWidget {
//   const TestNotificationWidget({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Test Notifications')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             // Create a test customer
//             final testCustomer = Customer(
//               contact: '1234567890',
//               wifiName: 'TestWiFi',
//               currentPassword: 'testpassword',
//               subscriptionStart: DateTime.now(),

//               isActive: true,
//               planType: PlanType.monthly,

//               name: 'John Doe',
//               subscriptionEnd: DateTime.now().add(Duration(seconds: 5)),
//             );

//             try {
//               await SubscriptionNotificationService.scheduleExpirationNotification(
//                 testCustomer,
//               );
//             } catch (e) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Failed to schedule notification: $e')),
//               );
//             }

//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text('Test notification scheduled!')),
//             );
//           },
//           child: const Text('Schedule Test Notification'),
//         ),
//       ),
//     );
//   }
// }

class NotificationStorageException implements Exception {
  final String message;
  NotificationStorageException(this.message);

  @override
  String toString() => message;
}
