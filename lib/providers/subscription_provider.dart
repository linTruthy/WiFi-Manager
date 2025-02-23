// // providers/subscription_provider.dart
// import 'package:riverpod/riverpod.dart';

// import '../database/models/customer.dart';
// import 'database_provider.dart';

// final expiringSubscriptionsProvider = StreamProvider<List<Customer>>((ref) async* {
//   final database = ref.watch(databaseProvider);

//   // Check every 15 minutes for expiring subscriptions
//   while (true) {
//     final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
//     final expiringCustomers = await database.getCustomersExpiringBefore(threeDaysFromNow);
//     yield expiringCustomers;
//     await Future.delayed(const Duration(minutes: 15));
//   }
// });
import 'package:riverpod/riverpod.dart';
import '../database/models/customer.dart';
import 'database_provider.dart';

final expiringSubscriptionsProvider = StreamProvider<List<Customer>>((ref) {
  final database = ref.watch(databaseProvider);
  final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));

  return database.firestore
      .collection(database.getUserCollectionPath('customers'))
      .where('isActive', isEqualTo: true)
      .where('subscriptionEnd',
          isLessThanOrEqualTo: threeDaysFromNow.toIso8601String())
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList());
});
