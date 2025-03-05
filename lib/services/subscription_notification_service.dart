// import 'dart:convert';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:logger/logger.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:permission_handler/permission_handler.dart';
// import '../database/models/customer.dart';
// import '../database/models/plan.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../main.dart';
// import '../screens/customer_detail_screen.dart';

// class SubscriptionNotificationService {
//   static final FlutterLocalNotificationsPlugin _notifications =
//       FlutterLocalNotificationsPlugin();
//   static const String channelId = 'subscription_notifications';
//   static const String channelName = 'Subscription Notifications';
//   static const String channelDescription =
//       'Notifications for expiring subscriptions';
//   static const _scheduledNotificationsKey = 'scheduled_notifications';
//   static final _logger = Logger(); // Add logging
//   // Notification settings stored in SharedPreferences
//   static const String _notificationSettingsKey = 'notification_settings';
//   static Map<String, dynamic> reminderSettings = {
//     'daysBeforeDaily': 0.1, // 2.4 hours for daily (default)
//     'daysBeforeWeekly': 1.5, // 1.5 days for weekly (default)
//     'daysBeforeMonthly': 3.0, // 3 days for monthly (default)
//     'priorityUrgent': true, // High priority for urgent (expiring today)
//     'enableSnooze': true, // Enable snooze option
//   };
//   static const MethodChannel _androidChannel =
//       MethodChannel('com.truthysystems.wifi/notification_scheduler');
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   static String _getUserCollectionPath(String collection) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) throw Exception('User not authenticated');
//     return 'users/${user.uid}/$collection';
//   }

//   static Future<void> _scheduleOnAndroid(
//     tz.TZDateTime time, String customerId) async {
//   if (Platform.isAndroid) {
//     final timeInMillis = time.millisecondsSinceEpoch;
//     await _androidChannel.invokeMethod('scheduleExactNotification', {
//       'timeInMillis': timeInMillis,
//       'customerId': customerId, // Keep as String
//     });
//   }
// }

//   static Future<void> initialize() async {
//     await _requestPermissions();
//     await _initializeNotifications();
//     _notifications.initialize(
//       const InitializationSettings(
//         android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//         iOS: DarwinInitializationSettings(),
//       ),
//       onDidReceiveNotificationResponse: (NotificationResponse response) async {
//         final payload = response.payload;
//         if (payload != null) {
//           await _handleNotificationResponse(payload);
//         }
//       },
//     );
//   }

//   static Future<void> _requestPermissions() async {
//     if (Platform.isAndroid) {
//       final status = await Permission.notification.status;
//       if (!status.isGranted) {
//         await Permission.notification.request();
//       }
//       final alarmStatus = await Permission.scheduleExactAlarm.status;
//       if (!alarmStatus.isGranted) {
//         final result = await Permission.scheduleExactAlarm.request();
//         if (!result.isGranted) {
//           _logger.log(Level.warning,
//               'Exact alarms denied, falling back to inexact alarms.');
//         }
//       }
//     }
//   }

//   static Future<void> scheduleAllNotifications() async {
//     try {
//       final snapshot = await _firestore
//           .collection(_getUserCollectionPath('customers'))
//           .where('isActive', isEqualTo: true)
//           .get();
//       final customers = snapshot.docs
//           .map((doc) => Customer.fromJson(doc.id, doc.data()))
//           .toList();
//       await scheduleExpirationNotifications(customers);
//       print('All notifications scheduled');
//     } on PlatformException catch (e) {
//       print("Failed to schedule all notifications: ${e.message}");
//     }
//   }

//   static Future<void> _initializeNotifications() async {
//     const androidChannel = AndroidNotificationChannel(
//       channelId,
//       channelName,
//       description: channelDescription,
//       importance: Importance.max,
//     );
//     final platform = _notifications.resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>();
//     await platform?.createNotificationChannel(androidChannel);
//     const initializationSettings = InitializationSettings(
//       android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//       iOS: DarwinInitializationSettings(),
//     );
//     await _notifications.initialize(initializationSettings);
//   }

//  static Future<void> scheduleExpirationNotifications(
//     List<Customer> customers) async {
//   final now = tz.TZDateTime.now(tz.local);
//   final notificationDetailsList = <Future<void>>[];
//   final scheduledCustomers = <Customer>[]; // Track customers actually scheduled
//   final scheduledTimes = <tz.TZDateTime>[]; // Track corresponding times

//   for (final customer in customers) {
//     if (await _isNotificationScheduled(customer.id)) continue;
//     final notificationTime = _calculateNotificationTime(customer);
//     if (notificationTime.isBefore(now)) {
//       await _scheduleImmediateNotification(customer);
//       await _scheduleOnAndroid(notificationTime, customer.id);
//       continue;
//     }
//     final importance = _getImportance(customer);
//     final notificationDetails = _createNotificationDetails(importance);
//     notificationDetailsList.add(_notifications.zonedSchedule(
//       customer.id.hashCode,
//       'Subscription Expiring',
//       _generateMessage(customer),
//       notificationTime,
//       notificationDetails,
//       androidScheduleMode: await _getScheduleMode(),
//       uiLocalNotificationDateInterpretation:
//           UILocalNotificationDateInterpretation.absoluteTime,
//       payload: customer.id.toString(),
//     ));
//   //  await _scheduleOnAndroid(notificationTime, customer.id);
//     scheduledCustomers.add(customer); // Add to tracked list
//     scheduledTimes.add(notificationTime); // Add corresponding time
//   }

//   try {
//     await Future.wait(notificationDetailsList);
//     await _saveScheduledNotifications(scheduledCustomers, scheduledTimes);
//   } catch (e) {
//     _logger.log(Level.error, 'Failed to schedule multiple notifications: $e');
//     await _retryScheduleNotifications(customers, 0);
//   }
// }

//   static Future<AndroidScheduleMode> _getScheduleMode() async {
//     if (Platform.isAndroid) {
//       final alarmStatus = await Permission.scheduleExactAlarm.status;
//       return alarmStatus.isGranted
//           ? AndroidScheduleMode.exactAllowWhileIdle
//           : AndroidScheduleMode.inexactAllowWhileIdle;
//     }
//     return AndroidScheduleMode.inexactAllowWhileIdle;
//   }

//   static Future<void> _retryScheduleNotifications(
//       List<Customer> customers, int retryCount) async {
//     if (retryCount >= 3) {
//       _logger.log(
//           Level.error, 'Max retries reached for scheduling notifications');
//       return;
//     }
//     await Future.delayed(Duration(seconds: 1 << retryCount));
//     try {
//       await scheduleExpirationNotifications(customers);
//     } catch (e) {
//       await _retryScheduleNotifications(customers, retryCount + 1);
//     }
//   }

//   static Importance _getImportance(Customer customer) {
//     final daysLeft = customer.subscriptionEnd.difference(DateTime.now()).inDays;
//     return daysLeft <= 0 && reminderSettings['priorityUrgent'] == true
//         ? Importance.max
//         : Importance.defaultImportance;
//   }

//   static NotificationDetails _createNotificationDetails(Importance importance) {
//     return NotificationDetails(
//       android: AndroidNotificationDetails(
//         channelId,
//         channelName,
//         channelDescription: channelDescription,
//         importance: importance,
//         priority: importance == Importance.max
//             ? Priority.high
//             : Priority.defaultPriority,
//         fullScreenIntent: importance == Importance.max,
//         showWhen: true,
//       ),
//     );
//   }

//   static Future<void> _scheduleImmediateNotification(Customer customer) async {
//     final notificationDetails = _createNotificationDetails(Importance.max);
//     try {
//       await _notifications.show(
//         customer.id.hashCode,
//         'Subscription Expiring Soon',
//         _generateMessage(customer),
//         notificationDetails,
//         payload: customer.id,
//       );
//     } catch (e) {
//       _logger.log(Level.error,
//           'Failed to show immediate notification for customer: ${customer.id}, Error: $e');
//     }
//   }

//   static Future<void> _saveScheduledNotifications(
//       List<Customer> customers, List<tz.TZDateTime> times) async {
//     final prefs = await SharedPreferences.getInstance();
//     final notifications = <String, dynamic>{};
//     final detailedNotifications = <String, dynamic>{};

//     for (int i = 0; i < customers.length; i++) {
//       final customer = customers[i];
//       final time = times[i];
//       final notificationDetails = {
//         'customerId': customer.id,
//         'customerName': customer.name,
//         'contact': customer.contact,
//         'wifiName': customer.wifiName,
//         'planType': customer.planType.toString().split('.').last,
//         'subscriptionStart': customer.subscriptionStart.toIso8601String(),
//         'subscriptionEnd': customer.subscriptionEnd.toIso8601String(),
//         'notificationTime': time.toIso8601String(),
//         'message': _generateMessage(customer),
//         'status': 'scheduled',
//         'isActive': customer.isActive,
//         'snoozeCount': 0, // Track snooze attempts
//       };
//       notifications[customer.id.toString()] = time.toIso8601String();
//       detailedNotifications[customer.id.toString()] = notificationDetails;
//     }

//     await prefs.setString(
//         _scheduledNotificationsKey, json.encode(notifications));
//     await prefs.setString(
//         'detailed_scheduled_notifications', json.encode(detailedNotifications));
//   }

//   static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final detailedNotificationsString =
//           prefs.getString('detailed_scheduled_notifications');
//       if (detailedNotificationsString == null) return [];
//       final Map<String, dynamic> decoded =
//           json.decode(detailedNotificationsString);
//       return decoded.values.map<Map<String, dynamic>>((notification) {
//         return {
//           'customerId':
//               int.tryParse(notification['customerId'].toString()) ?? 0,
//           'customerName': notification['customerName'],
//           'contact': notification['contact'],
//           'wifiName': notification['wifiName'],
//           'planType': notification['planType'],
//           'subscriptionStart':
//               DateTime.parse(notification['subscriptionStart']),
//           'subscriptionEnd': DateTime.parse(notification['subscriptionEnd']),
//           'notificationTime': DateTime.parse(notification['notificationTime']),
//           'message': notification['message'],
//           'status': notification['status'],
//           'isActive': notification['isActive'] ?? false,
//           'snoozeCount': notification['snoozeCount'] ?? 0,
//         };
//       }).toList();
//     } catch (e) {
//       _logger.log(
//           Level.error, 'Failed to get detailed scheduled notifications: $e');
//       throw NotificationStorageException('Failed to get notifications: $e');
//     }
//   }

//   static Future<void> loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     final settingsString = prefs.getString(_notificationSettingsKey);
//     if (settingsString != null) {
//       reminderSettings = json.decode(settingsString);
//     }
//   }

//   static Future<void> saveSettings(Map<String, dynamic> settings) async {
//     reminderSettings = settings;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_notificationSettingsKey, json.encode(settings));
//   }

//   static tz.TZDateTime _calculateNotificationTime(Customer customer) {
//     final end = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);
//     final daysBefore = _getDaysBefore(customer.planType);
//     return end.subtract(Duration(days: daysBefore.toInt()));
//   }

//   static double _getDaysBefore(PlanType planType) {
//     switch (planType) {
//       case PlanType.daily:
//         return reminderSettings['daysBeforeDaily'] as double;
//       case PlanType.weekly:
//         return reminderSettings['daysBeforeWeekly'] as double;
//       case PlanType.monthly:
//         return reminderSettings['daysBeforeMonthly'] as double;
//     }
//   }

//   static String _generateMessage(Customer customer) {
//     final now = DateTime.now();
//     final end = customer.subscriptionEnd;
//     final duration = end.difference(now);
//     final days = duration.inDays;
//     final hours = duration.inHours % 24;
//     final minutes = duration.inMinutes % 60;
//     String timeDescription;
//     if (days > 0) {
//       timeDescription =
//           '$days day${days != 1 ? 's' : ''}, $hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''} left';
//     } else if (hours > 0) {
//       timeDescription =
//           '$hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''} left';
//     } else {
//       timeDescription = '$minutes minute${minutes != 1 ? 's' : ''} left';
//     }
//     return '${customer.name}\'s ${customer.planType.name} plan expires in $timeDescription';
//   }

//   static Future<void> _handleNotificationResponse(String payload) async {
//     final context = navigatorKey.currentContext;
//     if (context == null) return;

//     final customerId = payload;
//     final customer = await _getCustomerById(customerId);
//     if (customer == null) return;

//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Subscription Reminder'),
//         content: Text(_generateMessage(customer)),
//         actions: [
//           if (reminderSettings['enableSnooze'] == true)
//             TextButton(
//               onPressed: () {
//                 _snoozeNotification(customer);
//                 Navigator.pop(context, true);
//               },
//               child: const Text('Snooze (30 min)'),
//             ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Dismiss'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context, true);
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) =>
//                       CustomerDetailScreen(customer: customer),
//                 ),
//               );
//             },
//             child: const Text('View Details'),
//           ),
//         ],
//       ),
//     );
//   }

//   static Future<void> _snoozeNotification(Customer customer) async {
//     final prefs = await SharedPreferences.getInstance();
//     final detailedNotificationsString =
//         prefs.getString('detailed_scheduled_notifications') ?? '{}';
//     final detailedNotifications =
//         json.decode(detailedNotificationsString) as Map<String, dynamic>;
//     final notification = detailedNotifications[customer.id];
//     if (notification != null) {
//       final snoozeCount = (notification['snoozeCount'] as int) + 1;
//       if (snoozeCount <= 3) {
//         final newTime = tz.TZDateTime.now(tz.local)
//             .add(Duration(minutes: 30 * snoozeCount));
//         notification['notificationTime'] = newTime.toIso8601String();
//         notification['snoozeCount'] = snoozeCount;
//         await _notifications.cancel(customer.id.hashCode);
//         await scheduleExpirationNotification(customer);
//         await prefs.setString('detailed_scheduled_notifications',
//             json.encode(detailedNotifications));
//       }
//     }
//   }
//   // static Widget _buildCustomerDetailScreen(String customerId) {
//   //   return FutureBuilder<Customer?>(
//   //     future: _getCustomerById(int.parse(customerId)),
//   //     builder: (context, snapshot) {
//   //       return AppRouter.buildLoadingOrError(
//   //         snapshot,
//   //         (data) => CustomerDetailScreen(customer: data),
//   //       );
//   //     },
//   //   );
//   // }

//   static Future<Customer?> _getCustomerById(String customerId) async {
//     final doc = await _firestore
//         .collection(_getUserCollectionPath('customers'))
//         .doc(customerId)
//         .get();
//     return doc.exists ? Customer.fromJson(doc.id, doc.data()!) : null;
//   }

//   static Future<void> scheduleExpirationNotification(Customer customer,
//       {int retryCount = 0}) async {
//     try {
//       if (await _isNotificationScheduled(customer.id)) return;
//       final notificationTime = _calculateNotificationTime(customer);
//       final now = tz.TZDateTime.now(tz.local);
//       if (notificationTime.isBefore(now)) {
//         await _scheduleImmediateNotification(customer);
//         await _scheduleOnAndroid(notificationTime, customer.id);
//         return;
//       }
//       final importance =
//           customer.subscriptionEnd.difference(DateTime.now()).inDays <= 0
//               ? Importance.max
//               : Importance.defaultImportance;
//       final notificationDetails = _createNotificationDetails(importance);
//       await _notifications.zonedSchedule(
//         customer.id.hashCode,
//         'Subscription Expiring',
//         _generateMessage(customer),
//         notificationTime,
//         notificationDetails,
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//         uiLocalNotificationDateInterpretation:
//             UILocalNotificationDateInterpretation.absoluteTime,
//         payload: customer.id.toString(),
//       );
//       await _saveScheduledNotification(customer, notificationTime);
//       await _markNotificationScheduled(customer.id, notificationTime);
//     } catch (e) {
//       if (retryCount < 3) {
//         await Future.delayed(
//             Duration(seconds: 1 << retryCount)); // Exponential backoff
//         await scheduleExpirationNotification(customer,
//             retryCount: retryCount + 1);
//       } else {
//         _logger.log(Level.error,
//             'Failed to schedule notification after retries for customer: ${customer.id}, Error: $e');
//       }
//     }
//   }

//   static Future<void> _saveScheduledNotification(
//     Customer customer,
//     tz.TZDateTime notificationTime,
//   ) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final scheduledNotificationsString =
//           prefs.getString('scheduled_notifications') ?? '{}';

//       // Parse existing notifications
//       final notifications =
//           json.decode(scheduledNotificationsString) as Map<String, dynamic>;

//       // Create a comprehensive notification object
//       final notificationDetails = {
//         'customerId': customer.id.toString(),
//         'customerName': customer.name,
//         'contact': customer.contact,
//         'wifiName': customer.wifiName,
//         'planType': customer.planType.toString().split('.').last,
//         'subscriptionStart': customer.subscriptionStart.toIso8601String(),
//         'subscriptionEnd': customer.subscriptionEnd.toIso8601String(),
//         'notificationTime': notificationTime.toIso8601String(),
//         'message': _generateMessage(customer),
//         'status': 'scheduled',
//         'isActive': customer.isActive,
//       };

//       // Store notification time for quick lookups
//       notifications[customer.id.toString()] =
//           notificationTime.toIso8601String();

//       // Save the updated notifications map
//       await prefs.setString(
//         'scheduled_notifications',
//         json.encode(notifications),
//       );

//       // Optionally, store the detailed notification information separately
//       final detailedNotificationsString =
//           prefs.getString('detailed_scheduled_notifications') ?? '{}';

//       final detailedNotifications =
//           json.decode(detailedNotificationsString) as Map<String, dynamic>;

//       detailedNotifications[customer.id.toString()] = notificationDetails;

//       await prefs.setString(
//         'detailed_scheduled_notifications',
//         json.encode(detailedNotifications),
//       );

//       _logger.log(
//         Level.info,
//         'Saved notification for customer: ${customer.id}',
//       );
//     } catch (e) {
//       _logger.log(Level.error, 'Failed to save notification: $e');
//       throw NotificationStorageException('Failed to save notification: $e');
//     }
//   }

//   // static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
//   //   try {
//   //     final prefs = await SharedPreferences.getInstance();
//   //     final detailedNotificationsString = prefs.getString(
//   //       'detailed_scheduled_notifications',
//   //     );

//   //     if (detailedNotificationsString == null) {
//   //       _logger.log(Level.info, 'No detailed scheduled notifications found');
//   //       return [];
//   //     }

//   //     final Map<String, dynamic> decoded = json.decode(
//   //       detailedNotificationsString,
//   //     );

//   //     final notifications =
//   //         decoded.values.map<Map<String, dynamic>>((notification) {
//   //       return {
//   //         'customerId':
//   //             int.tryParse(notification['customerId'].toString()) ?? 0,
//   //         'customerName': notification['customerName'],
//   //         'contact': notification['contact'],
//   //         'wifiName': notification['wifiName'],
//   //         'planType': notification['planType'],
//   //         'subscriptionStart': DateTime.parse(
//   //           notification['subscriptionStart'],
//   //         ),
//   //         'subscriptionEnd': DateTime.parse(
//   //           notification['subscriptionEnd'],
//   //         ),
//   //         'notificationTime': DateTime.parse(
//   //           notification['notificationTime'],
//   //         ),
//   //         'message': notification['message'],
//   //         'status': notification['status'],
//   //         'isActive': notification['isActive'] ?? false,
//   //       };
//   //     }).toList();

//   //     _logger.log(
//   //       Level.info,
//   //       'Retrieved ${notifications.length} detailed scheduled notifications',
//   //     );
//   //     return notifications;
//   //   } catch (e) {
//   //     _logger.log(
//   //       Level.error,
//   //       'Failed to get detailed scheduled notifications: $e',
//   //     );
//   //     throw NotificationStorageException(
//   //       'Failed to get detailed scheduled notifications: $e',
//   //     );
//   //   }
//   // }

//   // Helper method to safely parse customer ID
//   // static int _parseCustomerId(dynamic id) {
//   //   if (id == null) return 0;
//   //   if (id is int) return id;
//   //   if (id is String) return int.tryParse(id) ?? 0;
//   //   return 0;
//   // }

//   // // Helper method to safely parse DateTime
//   // static DateTime _parseDateTime(dynamic dateTime) {
//   //   if (dateTime == null) return DateTime.now();
//   //   if (dateTime is DateTime) return dateTime;
//   //   if (dateTime is String) {
//   //     try {
//   //       return DateTime.parse(dateTime);
//   //     } catch (e) {
//   //       _logger.log(Level.warning, 'Failed to parse date: $dateTime');
//   //       return DateTime.now();
//   //     }
//   //   }
//   //   return DateTime.now();
//   // }

//   // // Helper method to safely parse PlanType
//   // static PlanType _parsePlanType(dynamic planType) {
//   //   if (planType == null) return PlanType.monthly; // Default

//   //   // If it's already a PlanType, return it
//   //   if (planType is PlanType) return planType;

//   //   // If it's a string, try to match
//   //   if (planType is String) {
//   //     return PlanType.values.firstWhere(
//   //       (type) =>
//   //           type.toString().split('.').last.toLowerCase() ==
//   //           planType.toLowerCase(),
//   //       orElse: () => PlanType.monthly, // Default if no match
//   //     );
//   //   }

//   //   return PlanType.monthly; // Default
//   // }

//   static Future<bool> _isNotificationScheduled(String customerId) async {
//     final prefs = await SharedPreferences.getInstance();
//     final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
//     if (scheduledNotifications == null) return false;

//     final notifications =
//         json.decode(scheduledNotifications) as Map<String, dynamic>;
//     final scheduledTime = notifications[customerId];

//     if (scheduledTime == null) return false;

//     final notificationTime = DateTime.parse(scheduledTime);
//     return notificationTime.isAfter(DateTime.now());
//   }

//   static Future<void> _markNotificationScheduled(
//     String customerId,
//     tz.TZDateTime notificationTime,
//   ) async {
//     final prefs = await SharedPreferences.getInstance();
//     final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
//     final notifications = scheduledNotifications != null
//         ? json.decode(scheduledNotifications) as Map<String, dynamic>
//         : <String, dynamic>{};

//     notifications[customerId] = notificationTime.toString();
//     await prefs.setString(
//       _scheduledNotificationsKey,
//       json.encode(notifications),
//     );
//   }

//   static Future<void> clearExpiredNotifications() async {
//     final prefs = await SharedPreferences.getInstance();
//     final scheduledNotifications = prefs.getString(_scheduledNotificationsKey);
//     if (scheduledNotifications == null) return;

//     final notifications =
//         json.decode(scheduledNotifications) as Map<String, dynamic>;
//     notifications.removeWhere((_, timeStr) {
//       final time = DateTime.parse(timeStr);
//       return time.isBefore(DateTime.now());
//     });

//     await prefs.setString(
//       _scheduledNotificationsKey,
//       json.encode(notifications),
//     );
//   }

//   static Future<void> updateNotificationStatus(
//     int customerId,
//     String newStatus,
//   ) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final detailedNotificationsString = prefs.getString(
//         'detailed_scheduled_notifications',
//       );

//       if (detailedNotificationsString == null) return;

//       final Map<String, dynamic> notifications = json.decode(
//         detailedNotificationsString,
//       );

//       if (notifications.containsKey(customerId.toString())) {
//         notifications[customerId.toString()]['status'] = newStatus;

//         await prefs.setString(
//           'detailed_scheduled_notifications',
//           json.encode(notifications),
//         );

//         _logger.log(
//           Level.info,
//           'Updated notification status for customer: $customerId',
//         );
//       }
//     } catch (e) {
//       _logger.log(Level.error, 'Failed to update notification status: $e');
//     }
//   }
// }

// // class TestNotificationWidget extends StatelessWidget {
// //   const TestNotificationWidget({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Test Notifications')),
// //       body: Center(
// //         child: ElevatedButton(
// //           onPressed: () async {
// //             // Create a test customer
// //             final testCustomer = Customer(
// //               contact: '1234567890',
// //               wifiName: 'TestWiFi',
// //               currentPassword: 'testpassword',
// //               subscriptionStart: DateTime.now(),

// //               isActive: true,
// //               planType: PlanType.monthly,

// //               name: 'John Doe',
// //               subscriptionEnd: DateTime.now().add(Duration(seconds: 5)),
// //             );

// //             try {
// //               await SubscriptionNotificationService.scheduleExpirationNotification(
// //                 testCustomer,
// //               );
// //             } catch (e) {
// //               ScaffoldMessenger.of(context).showSnackBar(
// //                 SnackBar(content: Text('Failed to schedule notification: $e')),
// //               );
// //             }

// //             ScaffoldMessenger.of(context).showSnackBar(
// //               const SnackBar(content: Text('Test notification scheduled!')),
// //             );
// //           },
// //           child: const Text('Schedule Test Notification'),
// //         ),
// //       ),
// //     );
// //   }
// // }

// class NotificationStorageException implements Exception {
//   final String message;
//   NotificationStorageException(this.message);
//   @override
//   String toString() => message;
// }
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

  static tz.TZDateTime _calculateNotificationTime(Customer customer) {
    final endTime = tz.TZDateTime.from(customer.subscriptionEnd, tz.local);
    final daysBefore = _getDaysBefore(customer.planType);
    return endTime.subtract(Duration(days: daysBefore));
  }

  // static int _getDaysBefore(PlanType planType) {
  //   switch (planType) {
  //     case PlanType.daily:
  //       return 0; // Notify same day
  //     case PlanType.weekly:
  //       return 1; // Notify 1 day before
  //     case PlanType.monthly:
  //       return 3; // Notify 3 days before
  //   }
  // }

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
