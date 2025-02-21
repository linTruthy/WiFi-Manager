import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/subscription_notification_service.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/plan.dart';
import '../models/referral_stats.dart';
import '../models/sync_status.dart';

class DatabaseRepository {
  late Future<Isar> db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  DatabaseRepository() {
    db = openDB();
    _initializeSync();
  }

  Future<void> _initializeSync() async {
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi)) {
        if (kDebugMode) {
          print('Network available, triggering sync');
        }
        await syncPendingChanges();
      }
    });
  }

  Future<void> deletePayment(Id paymentId) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.payments.delete(paymentId);
      await isar.syncStatus.put(
        SyncStatus(
          entityId: paymentId,
          entityType: 'payment',
          operation: 'delete',
          timestamp: DateTime.now(),
        ),
      );
    });
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('payments'))
          .doc(paymentId.toString())
          .delete();
    }
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [
          CustomerSchema,
          PlanSchema,
          PaymentSchema,
          SyncStatusSchema,
          ReferralStatsSchema,
        ],
        directory: dir.path,
        name: 'wifi_manager',
      );
    }
    final isar = Isar.getInstance('wifi_manager');
    if (isar != null) {
      return isar;
    }
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [CustomerSchema, PlanSchema, PaymentSchema, SyncStatusSchema],
      directory: dir.path,
      name: 'wifi_manager',
    );
  }

  // Get the current user's Firestore collection path
  String _getUserCollectionPath(String collection) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return 'users/${user.uid}/$collection';
  }

  Future<void> saveCustomer(Customer customer) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.put(customer);
      await isar.syncStatus.put(
        SyncStatus(
          entityId: customer.id,
          entityType: 'customer',
          operation: 'save',
          timestamp: DateTime.now(),
        ),
      );
    });
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customer.id.toString())
          .set(customer.toJson());
    }
  }

  Future<void> deleteCustomer(Id customerId) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.delete(customerId);
      await isar.syncStatus.put(
        SyncStatus(
          entityId: customerId,
          entityType: 'customer',
          operation: 'delete',
          timestamp: DateTime.now(),
        ),
      );
    });
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customerId.toString())
          .delete();
    }
  }

  Future<List<Customer>> getActiveCustomers() async {
    final isar = await db;
    final customers =
        await isar.customers.filter().isActiveEqualTo(true).findAll();
    if (await isOnline()) {
      await _mergeCloudCustomers();
    }
    return customers;
  }

  Future<List<Customer>> getInactiveCustomers() async {
    final isar = await db;
    return await isar.customers.filter().isActiveEqualTo(false).findAll();
  }
// Future<List<Customer>> getInactiveCustomers() async {
//   final isar = await db;
//   return await isar.customers.filter((Customer customer) => !customer.isActive).findAll();
// }
  // Delete a customer and optionally all their associated data
  Future<void> deleteCustomerWithData(
    Id customerId,
    bool deleteAssociatedData,
  ) async {
    final isar = await db;
    await isar.writeTxn(() async {
      // Delete the customer
      await isar.customers.delete(customerId);

      if (deleteAssociatedData) {
        // Delete associated payments
        await isar.payments
            .filter()
            .customerIdEqualTo(customerId.toString())
            .deleteAll();

        // Delete associated referral stats
        await isar.referralStats
            .filter()
            .referrerIdEqualTo(customerId.toString())
            .deleteAll();
      }

      // Add a sync status record for the deletion
      await isar.syncStatus.put(
        SyncStatus(
          entityId: customerId,
          entityType: 'customer',
          operation: 'delete',
          timestamp: DateTime.now(),
        ),
      );
    });

    if (await isOnline()) {
      // Delete from Firestore
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customerId.toString())
          .delete();

      if (deleteAssociatedData) {
        // Delete associated payments from Firestore
        final paymentsSnapshot = await _firestore
            .collection(_getUserCollectionPath('payments'))
            .where('customerId', isEqualTo: customerId.toString())
            .get();
        for (final doc in paymentsSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete associated referral stats from Firestore
        final referralStatsSnapshot = await _firestore
            .collection(_getUserCollectionPath('referral_stats'))
            .where('referrerId', isEqualTo: customerId.toString())
            .get();
        for (final doc in referralStatsSnapshot.docs) {
          await doc.reference.delete();
        }
      }
    }
  }

  Future<void> savePayment(Payment payment) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.payments.put(payment);
      await isar.syncStatus.put(
        SyncStatus(
          entityId: payment.id,
          entityType: 'payment',
          operation: 'save',
          timestamp: DateTime.now(),
        ),
      );
    });
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('payments'))
          .doc(payment.id.toString())
          .set(payment.toJson());
    }
  }

  Future<void> syncPendingChanges() async {
    if (!await isOnline()) return;
    setSyncing(true);
    final isar = await db;
    final pendingSync = await isar.syncStatus.where().findAll();
    for (final status in pendingSync) {
      try {
        if (status.entityType == 'customer') {
          if (status.operation == 'save') {
            final customer = await isar.customers.get(status.entityId);
            if (customer != null) {
              await _syncCustomerToFirestore(customer);
            }
          } else if (status.operation == 'delete') {
            await _firestore
                .collection(_getUserCollectionPath('customers'))
                .doc(status.entityId.toString())
                .delete();
          }
        } else if (status.entityType == 'payment') {
          if (status.operation == 'save') {
            final payment = await isar.payments.get(status.entityId);
            if (payment != null) {
              await _syncPaymentToFirestore(payment);
            }
          } else if (status.operation == 'delete') {
            await _firestore
                .collection(_getUserCollectionPath('payments'))
                .doc(status.entityId.toString())
                .delete();
          }
        }
        await isar.writeTxn(() async {
          await isar.syncStatus.delete(status.id);
        });
      } catch (e) {
        if (kDebugMode) {
          print('Error syncing ${status.entityType} ${status.entityId}: $e');
        }
      }
    }
    await _mergeCloudPayments(); // Ensure cloud-to-local sync after local-to-cloud
    setSyncing(false);
  }

  void setSyncing(bool isSyncing) {
    _isSyncing = isSyncing;
  }

  Future<double> calculateActiveCustomerTrend() async {
    final isar = await db;
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final currentMonthCustomers = await isar.customers
        .filter()
        .isActiveEqualTo(true)
        .subscriptionStartLessThan(currentMonthStart)
        .findAll();
    final previousMonthCustomers = await isar.customers
        .filter()
        .isActiveEqualTo(true)
        .subscriptionStartLessThan(previousMonthStart)
        .findAll();
    if (previousMonthCustomers.isEmpty) {
      return 0.0;
    }
    final currentCount = currentMonthCustomers.length;
    final previousCount = previousMonthCustomers.length;
    final trend = ((currentCount - previousCount) / previousCount) * 100;
    return trend;
  }

  Future<List<ReferralStats>> getReferralStats(String referrerId) async {
    final isar = await db;
    return await isar.referralStats
        .filter()
        .referrerIdEqualTo(referrerId)
        .findAll();
  }

  Future<void> saveReferralStats(ReferralStats referralStats) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.referralStats.put(referralStats);
    });
  }

  Future<int> getTotalReferrals(String referrerId) async {
    final isar = await db;
    return await isar.referralStats
        .filter()
        .referrerIdEqualTo(referrerId)
        .count();
  }

  Future<Duration> getTotalRewardDuration(String referrerId) async {
    final isar = await db;
    final referrals = await isar.referralStats
        .filter()
        .referrerIdEqualTo(referrerId)
        .findAll();
    Duration totalReward = Duration.zero;
    for (final referral in referrals) {
      final rewardDuration = Duration(
        milliseconds: referral.rewardDurationMillis,
      );
      totalReward += rewardDuration;
    }
    return totalReward;
  }

  Future<void> _mergeCloudCustomers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('User not authenticated. Skipping Firestore sync.');
      }
      return;
    }

    final isar = await db;
    final snapshot =
        await _firestore.collection(_getUserCollectionPath('customers')).get();
    await isar.writeTxn(() async {
      for (final doc in snapshot.docs) {
        final cloudCustomer = Customer.fromJson(doc.data());
        final localCustomer = await isar.customers.get(cloudCustomer.id);
        if (localCustomer == null ||
            cloudCustomer.lastModified.isAfter(localCustomer.lastModified)) {
          await isar.customers.put(cloudCustomer);
        }
      }
    });
  }

  Future<void> _mergeCloudPayments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('User not authenticated. Skipping Firestore payment sync.');
      }
      return;
    }
    final isar = await db;
    final snapshot =
        await _firestore.collection(_getUserCollectionPath('payments')).get();
    await isar.writeTxn(() async {
      for (final doc in snapshot.docs) {
        final cloudPayment = Payment.fromJson(doc.data());
        final localPayment = await isar.payments.get(cloudPayment.id);
        if (localPayment == null ||
            cloudPayment.lastModified.isAfter(localPayment.lastModified)) {
          await isar.payments.put(cloudPayment);
        }
      }
    });
  }

  Future<void> _syncCustomerToFirestore(Customer customer) async {
    try {
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customer.id.toString())
          .set(customer.toJson());
      if (kDebugMode) {
        print('Customer ${customer.name} synced to Firestore');
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Error syncing customer ${customer.name} to Firestore: $e');
      }
    }
  }

  Future<void> _syncPaymentToFirestore(Payment payment) async {
    try {
      await _firestore
          .collection(_getUserCollectionPath('payments'))
          .doc(payment.id.toString())
          .set(payment.toJson());
      if (kDebugMode) {
        print('Customer ${payment.id} synced to Firestore');
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Error syncing customer ${payment.id} to Firestore: $e');
      }
    }
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
  }

  Future<List<Customer>> getExpiringCustomers() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final isar = await db;
    return await isar.customers
        .filter()
        .isActiveEqualTo(true)
        .subscriptionEndLessThan(tomorrow)
        .findAll();
  }

  Future<List<Customer>> getCustomersExpiringBefore(DateTime date) async {
    final isar = await db;
    return await isar.customers
        .filter()
        .isActiveEqualTo(true)
        .subscriptionEndLessThan(date)
        .findAll();
  }

  Future<List<Payment>> getRecentPayments() async {
    final isar = await db;
    if (await isOnline()) {
      await _mergeCloudPayments(); // Sync cloud payments to local
    }
    return await isar.payments
        .filter()
        .paymentDateGreaterThan(
            DateTime.now().subtract(const Duration(days: 60)))
        .findAll();
  }

  Future<void> deleteAllRecords() async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.where().deleteAll();
      await isar.payments.where().deleteAll();
      await isar.syncStatus.where().deleteAll();
    });
    if (await isOnline()) {
      final customerBatch = _firestore.batch();
      final paymentBatch = _firestore.batch();
      final customerDocs = await _firestore
          .collection(_getUserCollectionPath('customers'))
          .get();
      final paymentDocs =
          await _firestore.collection(_getUserCollectionPath('payments')).get();
      for (final doc in customerDocs.docs) {
        customerBatch.delete(doc.reference);
      }
      for (final doc in paymentDocs.docs) {
        paymentBatch.delete(doc.reference);
      }
      await customerBatch.commit();
      await paymentBatch.commit();
    }
  }

  pushPayment(Payment payment) async {
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('payments'))
          .doc(payment.id.toString())
          .set(payment.toJson());
    }
  }

  Future<void> activateCustomer(Id customerId) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final customer = await isar.customers.get(customerId);
      if (customer != null) {
        customer.isActive = true;
        await isar.customers.put(customer);
        await isar.syncStatus.put(
          SyncStatus(
            entityId: customer.id,
            entityType: 'customer',
            operation: 'save',
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customerId.toString())
          .update({'isActive': true});
    }
  }

  pushCustomer(Customer customer) async {
    if (await isOnline()) {
      await _firestore
          .collection(_getUserCollectionPath('customers'))
          .doc(customer.id.toString())
          .set(customer.toJson());
    }
  }
}

// Extension for notifications remains the same
extension NotificationExtension on DatabaseRepository {
  Future<void> scheduleNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        print('User not authenticated. Skipping notifications.');
      }
      return;
    }
    await Future.wait([scheduleExpirationNotifications()]);
  }

  Future<void> scheduleExpirationNotifications() async {
    final customers = await getActiveCustomers();

    for (final customer in customers) {
      await SubscriptionNotificationService.scheduleExpirationNotification(
        customer,
      );
    }
  }
}
