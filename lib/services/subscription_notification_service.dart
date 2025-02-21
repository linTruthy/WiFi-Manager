import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar/isar.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
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
  // Notification settings stored in SharedPreferences
  static const String _notificationSettingsKey = 'notification_settings';
  static Map<String, dynamic> reminderSettings = {
    'daysBeforeDaily': 0.1, // 2.4 hours for daily (default)
    'daysBeforeWeekly': 1.5, // 1.5 days for weekly (default)
    'daysBeforeMonthly': 3.0, // 3 days for monthly (default)
    'priorityUrgent': true, // High priority for urgent (expiring today)
    'enableSnooze': true, // Enable snooze option
  };
  static const MethodChannel _androidChannel =
      MethodChannel('com.truthysystems.wifi/notification_scheduler');
  static Future<void> _scheduleOnAndroid(
      tz.TZDateTime time, int customerId) async {
    if (Platform.isAndroid) {
      final timeInMillis = time.millisecondsSinceEpoch;
      await _androidChannel.invokeMethod('scheduleExactNotification', {
        'timeInMillis': timeInMillis,
        'customerId': customerId,
      });
    }
  }

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
          await _handleNotificationResponse(payload);
        }
      },
    );
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }

      final platform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (!alarmStatus.isGranted) {
        final result = await Permission.scheduleExactAlarm.request();
        if (!result.isGranted) {
          _logger.log(Level.warning,
              'Exact alarms denied, falling back to inexact alarms.');
        }
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
    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.createNotificationChannel(androidChannel);
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(initializationSettings);
  }

  static Future<void> scheduleExpirationNotifications(
      List<Customer> customers) async {
    final now = tz.TZDateTime.now(tz.local);
    final notificationDetailsList = <Future<void>>[];

    for (final customer in customers) {
      if (await _isNotificationScheduled(customer.id)) continue;
      final notificationTime = _calculateNotificationTime(customer);
      if (notificationTime.isBefore(now)) {
        await _scheduleImmediateNotification(customer);
        await _scheduleOnAndroid(notificationTime, customer.id);
        continue;
      }

      final importance = _getImportance(customer);
      final notificationDetails = _createNotificationDetails(importance);
      notificationDetailsList.add(_notifications.zonedSchedule(
        customer.id.hashCode,
        'Subscription Expiring',
        _generateMessage(customer),
        notificationTime,
        notificationDetails,
        androidScheduleMode: await _getScheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: customer.id.toString(),
      ));
      await _scheduleOnAndroid(notificationTime, customer.id);
    }

    try {
      await Future.wait(notificationDetailsList);
      await _saveScheduledNotifications(
          customers,
          notificationDetailsList
              .map((e) => _calculateNotificationTime(customers.first))
              .toList());
    } catch (e) {
      _logger.log(Level.error, 'Failed to schedule multiple notifications: $e');
      await _retryScheduleNotifications(customers, 0);
    }
  }

  static Future<AndroidScheduleMode> _getScheduleMode() async {
    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      return alarmStatus.isGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> _retryScheduleNotifications(
      List<Customer> customers, int retryCount) async {
    if (retryCount >= 3) {
      _logger.log(
          Level.error, 'Max retries reached for scheduling notifications');
      return;
    }
    await Future.delayed(Duration(seconds: 1 << retryCount));
    try {
      await scheduleExpirationNotifications(customers);
    } catch (e) {
      await _retryScheduleNotifications(customers, retryCount + 1);
    }
  }

  static Importance _getImportance(Customer customer) {
    final daysLeft = customer.subscriptionEnd.difference(DateTime.now()).inDays;
    return daysLeft <= 0 && reminderSettings['priorityUrgent'] == true
        ? Importance.max
        : Importance.defaultImportance;
  }

  static NotificationDetails _createNotificationDetails(Importance importance) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: importance == Importance.max
            ? Priority.high
            : Priority.defaultPriority,
        fullScreenIntent: importance == Importance.max,
        showWhen: true,
      ),
    );
  }

  static Future<void> _scheduleImmediateNotification(Customer customer) async {
    final notificationDetails = _createNotificationDetails(Importance.max);
    try {
      await _notifications.show(
        customer.id.hashCode,
        'Subscription Expiring Soon',
        _generateMessage(customer),
        notificationDetails,
        payload: customer.id.toString(),
      );
    } catch (e) {
      _logger.log(Level.error,
          'Failed to show immediate notification for customer: ${customer.id}, Error: $e');
    }
  }

  static Future<void> _saveScheduledNotifications(
      List<Customer> customers, List<tz.TZDateTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = <String, dynamic>{};
    final detailedNotifications = <String, dynamic>{};

    for (int i = 0; i < customers.length; i++) {
      final customer = customers[i];
      final time = times[i];
      final notificationDetails = {
        'customerId': customer.id.toString(),
        'customerName': customer.name,
        'contact': customer.contact,
        'wifiName': customer.wifiName,
        'planType': customer.planType.toString().split('.').last,
        'subscriptionStart': customer.subscriptionStart.toIso8601String(),
        'subscriptionEnd': customer.subscriptionEnd.toIso8601String(),
        'notificationTime': time.toIso8601String(),
        'message': _generateMessage(customer),
        'status': 'scheduled',
        'isActive': customer.isActive,
        'snoozeCount': 0, // Track snooze attempts
      };
      notifications[customer.id.toString()] = time.toIso8601String();
      detailedNotifications[customer.id.toString()] = notificationDetails;
    }

    await prefs.setString(
        _scheduledNotificationsKey, json.encode(notifications));
    await prefs.setString(
        'detailed_scheduled_notifications', json.encode(detailedNotifications));
  }

  static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailedNotificationsString =
          prefs.getString('detailed_scheduled_notifications');
      if (detailedNotificationsString == null) return [];
      final Map<String, dynamic> decoded =
          json.decode(detailedNotificationsString);
      return decoded.values.map<Map<String, dynamic>>((notification) {
        return {
          'customerId':
              int.tryParse(notification['customerId'].toString()) ?? 0,
          'customerName': notification['customerName'],
          'contact': notification['contact'],
          'wifiName': notification['wifiName'],
          'planType': notification['planType'],
          'subscriptionStart':
              DateTime.parse(notification['subscriptionStart']),
          'subscriptionEnd': DateTime.parse(notification['subscriptionEnd']),
          'notificationTime': DateTime.parse(notification['notificationTime']),
          'message': notification['message'],
          'status': notification['status'],
          'isActive': notification['isActive'] ?? false,
          'snoozeCount': notification['snoozeCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      _logger.log(
          Level.error, 'Failed to get detailed scheduled notifications: $e');
      throw NotificationStorageException('Failed to get notifications: $e');
    }
  }

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsString = prefs.getString(_notificationSettingsKey);
    if (settingsString != null) {
      reminderSettings = json.decode(settingsString);
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    reminderSettings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationSettingsKey, json.encode(settings));
  }

  static tz.TZDateTime _calculateNotificationTime(Customer customer) {
    final end = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);
    final daysBefore = _getDaysBefore(customer.planType);
    return end.subtract(Duration(days: daysBefore.toInt()));
  }

  static double _getDaysBefore(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return reminderSettings['daysBeforeDaily'] as double;
      case PlanType.weekly:
        return reminderSettings['daysBeforeWeekly'] as double;
      case PlanType.monthly:
        return reminderSettings['daysBeforeMonthly'] as double;
    }
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
          '$days day${days != 1 ? 's' : ''}, $hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''} left';
    } else if (hours > 0) {
      timeDescription =
          '$hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''} left';
    } else {
      timeDescription = '$minutes minute${minutes != 1 ? 's' : ''} left';
    }
    return '${customer.name}\'s ${customer.planType.name} plan expires in $timeDescription';
  }

  static Future<void> _handleNotificationResponse(String payload) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final customerId = int.parse(payload);
    final customer = await _getCustomerById(customerId);
    if (customer == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Subscription Reminder'),
        content: Text(_generateMessage(customer)),
        actions: [
          if (reminderSettings['enableSnooze'] == true)
            TextButton(
              onPressed: () {
                _snoozeNotification(customer);
                Navigator.pop(context, true);
              },
              child: const Text('Snooze (30 min)'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomerDetailScreen(customer: customer),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  static Future<void> _snoozeNotification(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    final detailedNotificationsString =
        prefs.getString('detailed_scheduled_notifications') ?? '{}';
    final detailedNotifications =
        json.decode(detailedNotificationsString) as Map<String, dynamic>;
    final notification = detailedNotifications[customer.id.toString()];
    if (notification != null) {
      final snoozeCount = (notification['snoozeCount'] as int) + 1;
      if (snoozeCount <= 3) {
        // Limit snooze to 3 times
        final newTime = tz.TZDateTime.now(tz.local)
            .add(Duration(minutes: 30 * snoozeCount));
        notification['notificationTime'] = newTime.toIso8601String();
        notification['snoozeCount'] = snoozeCount;
        await _notifications.cancel(customer.id.hashCode);
        await scheduleExpirationNotification(customer);
        await prefs.setString('detailed_scheduled_notifications',
            json.encode(detailedNotifications));
      }
    }
  }

  // static Widget _buildCustomerDetailScreen(String customerId) {
  //   return FutureBuilder<Customer?>(
  //     future: _getCustomerById(int.parse(customerId)),
  //     builder: (context, snapshot) {
  //       return AppRouter.buildLoadingOrError(
  //         snapshot,
  //         (data) => CustomerDetailScreen(customer: data),
  //       );
  //     },
  //   );
  // }

  static Future<Customer?> _getCustomerById(int customerId) async {
    final isar = Isar.getInstance('wifi_manager');
    return await isar?.customers.get(customerId);
  }

  static Future<void> scheduleExpirationNotification(Customer customer,
      {int retryCount = 0}) async {
    try {
      if (await _isNotificationScheduled(customer.id)) return;
      final notificationTime = _calculateNotificationTime(customer);
      final now = tz.TZDateTime.now(tz.local);
      if (notificationTime.isBefore(now)) {
        await _scheduleImmediateNotification(customer);
        await _scheduleOnAndroid(notificationTime, customer.id);
        return;
      }
      final importance =
          customer.subscriptionEnd.difference(DateTime.now()).inDays <= 0
              ? Importance.max
              : Importance.defaultImportance;
      final notificationDetails = _createNotificationDetails(importance);
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
    } catch (e) {
      if (retryCount < 3) {
        await Future.delayed(
            Duration(seconds: 1 << retryCount)); // Exponential backoff
        await scheduleExpirationNotification(customer,
            retryCount: retryCount + 1);
      } else {
        _logger.log(Level.error,
            'Failed to schedule notification after retries for customer: ${customer.id}, Error: $e');
      }
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

  // static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final detailedNotificationsString = prefs.getString(
  //       'detailed_scheduled_notifications',
  //     );

  //     if (detailedNotificationsString == null) {
  //       _logger.log(Level.info, 'No detailed scheduled notifications found');
  //       return [];
  //     }

  //     final Map<String, dynamic> decoded = json.decode(
  //       detailedNotificationsString,
  //     );

  //     final notifications =
  //         decoded.values.map<Map<String, dynamic>>((notification) {
  //       return {
  //         'customerId':
  //             int.tryParse(notification['customerId'].toString()) ?? 0,
  //         'customerName': notification['customerName'],
  //         'contact': notification['contact'],
  //         'wifiName': notification['wifiName'],
  //         'planType': notification['planType'],
  //         'subscriptionStart': DateTime.parse(
  //           notification['subscriptionStart'],
  //         ),
  //         'subscriptionEnd': DateTime.parse(
  //           notification['subscriptionEnd'],
  //         ),
  //         'notificationTime': DateTime.parse(
  //           notification['notificationTime'],
  //         ),
  //         'message': notification['message'],
  //         'status': notification['status'],
  //         'isActive': notification['isActive'] ?? false,
  //       };
  //     }).toList();

  //     _logger.log(
  //       Level.info,
  //       'Retrieved ${notifications.length} detailed scheduled notifications',
  //     );
  //     return notifications;
  //   } catch (e) {
  //     _logger.log(
  //       Level.error,
  //       'Failed to get detailed scheduled notifications: $e',
  //     );
  //     throw NotificationStorageException(
  //       'Failed to get detailed scheduled notifications: $e',
  //     );
  //   }
  // }

  // Helper method to safely parse customer ID
  // static int _parseCustomerId(dynamic id) {
  //   if (id == null) return 0;
  //   if (id is int) return id;
  //   if (id is String) return int.tryParse(id) ?? 0;
  //   return 0;
  // }

  // // Helper method to safely parse DateTime
  // static DateTime _parseDateTime(dynamic dateTime) {
  //   if (dateTime == null) return DateTime.now();
  //   if (dateTime is DateTime) return dateTime;
  //   if (dateTime is String) {
  //     try {
  //       return DateTime.parse(dateTime);
  //     } catch (e) {
  //       _logger.log(Level.warning, 'Failed to parse date: $dateTime');
  //       return DateTime.now();
  //     }
  //   }
  //   return DateTime.now();
  // }

  // // Helper method to safely parse PlanType
  // static PlanType _parsePlanType(dynamic planType) {
  //   if (planType == null) return PlanType.monthly; // Default

  //   // If it's already a PlanType, return it
  //   if (planType is PlanType) return planType;

  //   // If it's a string, try to match
  //   if (planType is String) {
  //     return PlanType.values.firstWhere(
  //       (type) =>
  //           type.toString().split('.').last.toLowerCase() ==
  //           planType.toLowerCase(),
  //       orElse: () => PlanType.monthly, // Default if no match
  //     );
  //   }

  //   return PlanType.monthly; // Default
  // }

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
    final notifications = scheduledNotifications != null
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
