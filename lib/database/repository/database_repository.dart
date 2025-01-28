import 'package:isar/isar.dart';
import 'package:myapp/database/models/customer.dart';
import 'package:myapp/database/models/payment.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/notification_service.dart';
import '../models/plan.dart';

class DatabaseRepository {
  late Future<Isar> db;

  DatabaseRepository() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [CustomerSchema, PlanSchema, PaymentSchema],
        directory: dir.path,
        name: 'wifi_manager',
      );
    }

    return Future.value(Isar.getInstance());
  }

  // Customer operations
  Future<void> saveCustomer(Customer customer) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.customers.put(customer);
    });
  }

  Future<List<Customer>> getCustomersExpiringBefore(DateTime date) async {
    final isar = await db;
    return await isar.customers
        .filter()
        .isActiveEqualTo(true)
        .subscriptionEndLessThan(date)
        .findAll();
  }

  Future<List<Customer>> getActiveCustomers() async {
    final isar = await db;
    return await isar.customers.filter().isActiveEqualTo(true).findAll();
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

  // Payment operations
  Future<void> savePayment(Payment payment) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.payments.put(payment);
    });
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
}

// Extension of DatabaseRepository to handle notifications
extension NotificationExtension on DatabaseRepository {
  Future<void> schedulePaymentReminders() async {
    final customers = await getActiveCustomers();

    for (final customer in customers) {
      // Schedule reminder if subscription ends within the next 3 days
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

  double _getPlanAmount(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return 5.0;
      case PlanType.weekly:
        return 25.0;
      case PlanType.monthly:
        return 80.0;
    }
  }
}
