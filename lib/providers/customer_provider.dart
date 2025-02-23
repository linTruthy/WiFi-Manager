// import 'package:riverpod/riverpod.dart';

// import '../database/models/customer.dart';
// import 'database_provider.dart';

// final customerProvider = FutureProvider.family<Customer?, String>((
//   ref,
//   customerId,
// ) async {
//   final database = ref.watch(databaseProvider);
//   final isar = await database.db;
//   return await isar.customers.get(int.parse(customerId));
// });
// // final inactiveCustomersProvider = FutureProvider<List<Customer>>((ref) async {
// //   final database = ref.watch(databaseProvider);
// //   return database.getInactiveCustomers();
// // });
// final inactiveCustomersProvider = FutureProvider<List<Customer>>((ref) async {
//   final database = ref.watch(databaseProvider);
//   return database.getInactiveCustomers();
// });
import 'package:riverpod/riverpod.dart';
import '../database/models/customer.dart';
import 'database_provider.dart';

final customerProvider =
    FutureProvider.family<Customer?, String>((ref, customerId) async {
  final database = ref.watch(databaseProvider);
  final snapshot = await database.firestore
      .collection(database.getUserCollectionPath('customers'))
      .doc(customerId)
      .get();
  return snapshot.exists
      ? Customer.fromJson(snapshot.id, snapshot.data()!)
      : null;
});

final inactiveCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getInactiveCustomers();
});
