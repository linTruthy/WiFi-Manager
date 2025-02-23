// import 'dart:async';

// import '../database/repository/database_repository.dart';

// class NotificationScheduler {
//   final DatabaseRepository _repository;
//   Timer? _schedulingTimer;

//   NotificationScheduler(this._repository) {
//   _scheduleNotificationCheck();
//   _schedulingTimer = Timer.periodic(const Duration(hours: 6), (_) => _scheduleNotificationCheck());
// }

//   Future<void> _scheduleNotificationCheck() async {
//     try {
//       await _repository.scheduleNotifications();
//     } catch (e) {
//       // Implement proper error logging here
//     }
//   }

//   void dispose() {
//     _schedulingTimer?.cancel();
//   }
// }
// // import 'dart:async';
// // import 'package:workmanager/workmanager.dart';
// // import '../database/repository/database_repository.dart';

// // class NotificationScheduler {
// //   final DatabaseRepository _repository;

// //   NotificationScheduler(this._repository) {
// //     _initializeWorkManager();
// //   }

// //   void _initializeWorkManager() {
// //     Workmanager().initialize(
// //       callbackDispatcher,
// //       isInDebugMode: true,
// //     );
// //     Workmanager().registerPeriodicTask(
// //       "notification-check",
// //       "checkNotifications",
// //       frequency: const Duration(hours: 6), // Check every 6 hours
// //       constraints: Constraints(
// //         networkType: NetworkType.connected,
// //       ),
// //     );
// //   }

// //   static void callbackDispatcher() {
// //     Workmanager().executeTask((task, inputData) async {
// //       final repository = DatabaseRepository();
// //       await repository.scheduleNotifications();
// //       return Future.value(true);
// //     });
// //   }

// //   void dispose() {
// //     // No need to cancel Timer since we're using WorkManager
// //   }
// // }
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/models/customer.dart';
import '../services/subscription_notification_service.dart';

class NotificationScheduler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _schedulingTimer;

  NotificationScheduler() {
    _scheduleNotificationCheck();
    _schedulingTimer = Timer.periodic(
        const Duration(hours: 6), (_) => _scheduleNotificationCheck());
  }

  String _getUserCollectionPath(String collection) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return 'users/${user.uid}/$collection';
  }

  Future<void> _scheduleNotificationCheck() async {
    try {
      // Fetch active customers directly from Firestore
      final snapshot = await _firestore
          .collection(_getUserCollectionPath('customers'))
          .where('isActive', isEqualTo: true)
          .get();

      final customers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();

      // Schedule notifications using SubscriptionNotificationService
      await SubscriptionNotificationService.scheduleExpirationNotifications(
          customers);
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  void dispose() {
    _schedulingTimer?.cancel();
  }
}
