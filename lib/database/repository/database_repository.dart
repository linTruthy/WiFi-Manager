import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../services/notification_service.dart';
import '../../services/subscription_notification_service.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/plan.dart';
import '../models/sync_status.dart';

/// Repository that handles both local (Isar) and cloud (Firestore) storage
class DatabaseRepository {
  late Future<Isar> db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  // Collection references
  static const String _customersCollection = 'customers';
  static const String _paymentsCollection = 'payments';

  DatabaseRepository() {
    db = openDB();
    _initializeSync();
  }

  Future<void> _initializeSync() async {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi)) {
        syncPendingChanges();
      }
    });
  }

Future<Isar> openDB() async {
  if (Isar.instanceNames.isEmpty) {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [CustomerSchema, PlanSchema, PaymentSchema, SyncStatusSchema],
      directory: dir.path,
      name: 'wifi_manager',
    );
  }
  
  // Get existing instance with the specific name
  final isar = Isar.getInstance('wifi_manager');
  if (isar != null) {
    return isar;
  }
  
  // If instance with name doesn't exist, create new one
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [CustomerSchema, PlanSchema, PaymentSchema, SyncStatusSchema],
    directory: dir.path,
    name: 'wifi_manager',
  );
}

  // Customer operations with sync
  Future<void> saveCustomer(Customer customer) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.put(customer);
      // Mark for sync
      await isar.syncStatus.put(
        SyncStatus(
          entityId: customer.id,
          entityType: 'customer',
          operation: 'save',
          timestamp: DateTime.now(),
        ),
      );
    });

    // Try immediate sync if online
    if (await _isOnline()) {
      await _syncCustomerToFirestore(customer);
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

    if (await _isOnline()) {
      await _firestore
          .collection(_customersCollection)
          .doc(customerId.toString())
          .delete();
    }
  }

  Future<List<Customer>> getActiveCustomers() async {
    final isar = await db;
    final customers =
        await isar.customers.filter().isActiveEqualTo(true).findAll();

    // If online, merge with cloud data
    if (await _isOnline()) {
      await _mergeCloudCustomers();
    }

    return customers;
  }

  // Payment operations with sync
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

    if (await _isOnline()) {
      await _syncPaymentToFirestore(payment);
    }
  }

  // Sync operations
  Future<void> syncPendingChanges() async {
    if (!await _isOnline()) return;

    final isar = await db;
    final pendingSync = await isar.syncStatus.where().findAll();

    for (final status in pendingSync) {
      try {
        if (status.entityType == 'customer') {
          final customer = await isar.customers.get(status.entityId);
          if (customer != null) {
            await _syncCustomerToFirestore(customer);
          }
        } else if (status.entityType == 'payment') {
          final payment = await isar.payments.get(status.entityId);
          if (payment != null) {
            await _syncPaymentToFirestore(payment);
          }
        }

        // Remove sync status after successful sync
        await isar.writeTxn(() async {
          await isar.syncStatus.delete(status.id);
        });
      } catch (e) {
        print('Error syncing ${status.entityType} ${status.entityId}: $e');
        // Could implement retry logic here
      }
    }
  }

  Future<void> _mergeCloudCustomers() async {
    final isar = await db;
    final snapshot = await _firestore.collection(_customersCollection).get();

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

  Future<void> _syncCustomerToFirestore(Customer customer) async {
    await _firestore
        .collection(_customersCollection)
        .doc(customer.id.toString())
        .set(customer.toJson());
  }

  Future<void> _syncPaymentToFirestore(Payment payment) async {
    await _firestore
        .collection(_paymentsCollection)
        .doc(payment.id.toString())
        .set(payment.toJson());
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    // Suggested code may be subject to a license. Learn more: ~LicenseLog:3950631877.
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
    return await isar.payments
        .filter()
        .paymentDateGreaterThan(
          DateTime.now().subtract(const Duration(days: 30)),
        )
        .findAll();
  }

  // Bulk operations
  Future<void> deleteAllRecords() async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.where().deleteAll();
      await isar.payments.where().deleteAll();
      await isar.syncStatus.where().deleteAll();
    });

    if (await _isOnline()) {
      // Delete all cloud records
      final customerBatch = _firestore.batch();
      final paymentBatch = _firestore.batch();

      final customerDocs =
          await _firestore.collection(_customersCollection).get();
      final paymentDocs =
          await _firestore.collection(_paymentsCollection).get();

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
}

// Extension for notifications remains the same
extension NotificationExtension on DatabaseRepository {
  Future<void> scheduleNotifications() async {
    await Future.wait([
      schedulePaymentReminders(),
      scheduleExpirationNotifications(),
    ]);
  }

  Future<void> schedulePaymentReminders() async {
    final customers = await getActiveCustomers();

    for (final customer in customers) {
      final daysUntilExpiry =
          customer.subscriptionEnd.difference(DateTime.now()).inDays;

      if (daysUntilExpiry <= 3 && daysUntilExpiry > 0) {
        final amount = _getPlanAmount(customer.planType);
        await NotificationService.schedulePaymentReminder(
          customerId: customer.id,
          customerName: customer.name,
          dueDate: customer.subscriptionEnd,
          amount: amount,
        );
      }
    }
  }

  Future<void> scheduleExpirationNotifications() async {
    final customers = await getActiveCustomers();

    for (final customer in customers) {
      await SubscriptionNotificationService.scheduleExpirationNotification(
        customer,
      );
    }
  }

  double _getPlanAmount(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return 2000.0;
      case PlanType.weekly:
        return 10000.0;
      case PlanType.monthly:
        return 35000.0;
    }
  }
}
