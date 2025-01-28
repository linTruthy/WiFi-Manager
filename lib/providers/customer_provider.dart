import 'package:riverpod/riverpod.dart';

import '../database/models/customer.dart';
import 'database_provider.dart';

final customerProvider = FutureProvider.family<Customer?, String>((
  ref,
  customerId,
) async {
  final database = ref.watch(databaseProvider);
  final isar = await database.db;
  return await isar.customers.get(int.parse(customerId));
});
