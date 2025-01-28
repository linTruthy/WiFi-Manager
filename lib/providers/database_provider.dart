import 'package:riverpod/riverpod.dart';

import '../database/models/customer.dart';
import '../database/models/payment.dart';
import '../database/repository/database_repository.dart';

final databaseProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository();
});

final activeCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getActiveCustomers();
});

final expiringCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getExpiringCustomers();
});

final recentPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getRecentPayments();
});