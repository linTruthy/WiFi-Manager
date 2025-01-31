import 'package:riverpod/riverpod.dart';

import 'database_provider.dart';

final activeCustomerTrendProvider = FutureProvider<double>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.calculateActiveCustomerTrend();
});