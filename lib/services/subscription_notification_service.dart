
import 'package:android_intent_plus/android_intent.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../database/models/customer.dart';
import '../database/models/plan.dart';
import 'package:permission_handler/permission_handler.dart';

class SubscriptionNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Logger _logger = Logger();
  static const String _channelId = 'subscription_notifications';
  static const String _channelName = 'Subscription Notifications';
  static const String _channelDescription =
      'Notifications for expiring subscriptions';
  static const String _scheduledNotificationsKey = 'scheduled_notifications';
  static const int _maxRetries = 3;
  static Map<String, dynamic> reminderSettings = {
    'daysBeforeDaily': 0,
    'daysBeforeWeekly': 1,
    'daysBeforeMonthly': 3,
  };
  static const String _detailedNotificationsKey =
      'detailed_scheduled_notifications';

  static Future<void> initialize() async {
    _requestPermissions();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          await _handleNotificationTap(response.payload!);
        }
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
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

  /// Load settings from SharedPreferences
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsString = prefs.getString('notification_settings');
    if (settingsString != null) {
      reminderSettings = json.decode(settingsString);
    }
  }

  /// Save settings to SharedPreferences
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    reminderSettings = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_settings', json.encode(settings));
  }

  /// Get the number of days before notification based on plan type
  static int _getDaysBefore(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return reminderSettings['daysBeforeDaily'] as int? ?? 0;
      case PlanType.weekly:
        return reminderSettings['daysBeforeWeekly'] as int? ?? 1;
      case PlanType.monthly:
        return reminderSettings['daysBeforeMonthly'] as int? ?? 3;
    }
  }

  static Future<void> scheduleExpirationNotifications(
      List<Customer> customers) async {
    final now = tz.TZDateTime.now(tz.local);
    final futures = <Future<void>>[];
    _logger.i('scheduling...');
    for (final customer in customers) {
      final notificationTime = _calculateNotificationTime(customer);
      if (await _isNotificationScheduled(customer.id)) continue;

      if (notificationTime.isBefore(now)) {
        await _showImmediateNotification(customer);
        continue;
      }
      futures.add(_scheduleNotificationWithRetry(customer, notificationTime));
    }
    try {
      await Future.wait(futures);
      _logger.i('Successfully scheduled ${futures.length} notifications');
    } catch (e) {
      _logger.e('Failed to schedule notifications: $e');
      rethrow;
    }
  }

  static Future<void> _scheduleNotificationWithRetry(
      Customer customer, tz.TZDateTime notificationTime,
      [int retryCount = 0]) async {
    try {
      final details = _createNotificationDetails(customer);
      await _notifications.zonedSchedule(
        customer.id.hashCode,
        'Subscription Expiring',
        _generateMessage(customer),
        notificationTime,
        details,
        androidScheduleMode:
            await _getScheduleMode(), // AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: customer.id,
      );

      await _saveScheduledNotification(customer, notificationTime);
      _logger.i(
          'Scheduled notification for ${customer.name} at $notificationTime');
    } catch (e) {
      if (retryCount < _maxRetries) {
        final delay = Duration(seconds: 1 << retryCount);
        _logger.w(
            'Retry ${retryCount + 1}/$_maxRetries for ${customer.id} after $e');
        await Future.delayed(delay);
        await _scheduleNotificationWithRetry(
            customer, notificationTime, retryCount + 1);
      } else {
        _logger.e(
            'Failed to schedule notification for ${customer.id} after $_maxRetries retries: $e');
        throw NotificationSchedulingException(
            'Max retries exceeded for ${customer.id}: $e');
      }
    }
  }

  static Future<void> _showImmediateNotification(Customer customer) async {
    final details = _createNotificationDetails(customer, isUrgent: true);
    await _notifications.show(
      customer.id.hashCode,
      'Subscription Expiring Soon',
      _generateMessage(customer),
      details,
      payload: customer.id,
    );
    _logger.i('Showed immediate notification for ${customer.name}');
  }

  static NotificationDetails _createNotificationDetails(Customer customer,
      {bool isUrgent = false}) {
    final importance =
        isUrgent || customer.subscriptionEnd.isBefore(DateTime.now())
            ? Importance.max
            : Importance.defaultImportance;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: importance,
        priority: importance == Importance.max
            ? Priority.high
            : Priority.defaultPriority,
        showWhen: true,
      ),
    );
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

  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: Uri.parse('package:com.truthysystems.wifi').toString(),
      );
      await intent.launch();
    }
  }

  static tz.TZDateTime _calculateNotificationTime(Customer customer) {
    final endTime = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);
    final daysBefore = _getDaysBefore(customer.planType);
    return endTime.subtract(Duration(days: daysBefore));
  }

  static String _generateMessage(Customer customer) {
    final duration = customer.subscriptionEnd.difference(DateTime.now());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    return days > 0
        ? '${customer.name}’s ${customer.planType.name} plan expires in $days day${days > 1 ? 's' : ''}'
        : '${customer.name}’s ${customer.planType.name} plan expires in $hours hour${hours > 1 ? 's' : ''}';
  }

  static Future<void> _saveScheduledNotification(
      Customer customer, tz.TZDateTime notificationTime) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications =
        prefs.getString(_detailedNotificationsKey)?.let(json.decode) ??
            <String, dynamic>{};

    notifications[customer.id] = {
      'customerId': customer.id,
      'customerName': customer.name,
      'planType': customer.planType.name,
      'subscriptionEnd': customer.subscriptionEnd.toIso8601String(),
      'notificationTime': notificationTime.toIso8601String(),
      'message':
          'Reminder: ${customer.name}\'s ${customer.planType.name} plan ends soon',
      'status': 'scheduled',
    };

    await prefs.setString(
        _detailedNotificationsKey, json.encode(notifications));
  }

  static Future<bool> _isNotificationScheduled(String customerId) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications =
        prefs.getString(_scheduledNotificationsKey)?.let(json.decode) ??
            <String, dynamic>{};
    final scheduled = notifications[customerId];
    if (scheduled == null) return false;

    final time = DateTime.parse(scheduled['time']);
    return time.isAfter(DateTime.now());
  }

  static Future<void> _handleNotificationTap(String customerId) async {
    _logger.i('Notification tapped for customer: $customerId');
    // Add navigation logic here if needed
  }

  static Future<void> clearExpiredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications =
        prefs.getString(_scheduledNotificationsKey)?.let(json.decode) ??
            <String, dynamic>{};
    notifications.removeWhere(
        (_, data) => DateTime.parse(data['time']).isBefore(DateTime.now()));
    await prefs.setString(
        _scheduledNotificationsKey, json.encode(notifications));
  }

  static Future<void> scheduleSingleExpirationNotification(
      Customer customer) async {
    await _notifications.cancel(customer.id.hashCode);
    await scheduleExpirationNotifications([customer]);
  }

  static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    _logger.i('Fetching scheduled notifications'); // Log method start
    final prefs = await SharedPreferences.getInstance();
    final notificationsString = prefs.getString(_detailedNotificationsKey);

    if (notificationsString == null) {
      _logger.w(
          'No notifications found in SharedPreferences'); // Log if no data exists
      return [];
    }

    try {
      final notifications =
          json.decode(notificationsString) as Map<String, dynamic>;
      final now = DateTime.now();

      // Filter out expired notifications
      final activeNotifications = notifications.entries
          .where((entry) =>
              DateTime.parse(entry.value['notificationTime']).isAfter(now))
          .map((entry) => entry.value)
          .toList();

      _logger.i(
          'Found ${activeNotifications.length} active notifications'); // Log count of active notifications

      // Parse and return the active notifications
      return activeNotifications
          .map((notification) => {
                'customerId': notification['customerId'],
                'customerName': notification['customerName'],
                'planType': notification['planType'],
                'subscriptionEnd':
                    DateTime.parse(notification['subscriptionEnd']),
                'notificationTime':
                    DateTime.parse(notification['notificationTime']),
                'message': notification['message'],
                'status': notification['status'],
              })
          .toList();
    } catch (e) {
      _logger.e('Error decoding notifications: $e'); // Log any errors
      return [];
    }
  }
}

class NotificationSchedulingException implements Exception {
  final String message;
  NotificationSchedulingException(this.message);
  @override
  String toString() => message;
}

extension StringExtension on String {
  T? let<T>(T Function(String) transform) => transform(this);
}
