import 'package:riverpod/riverpod.dart';
import 'database_provider.dart';

final retentionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  final activeCustomers = await db.getActiveCustomers();
  final inactiveCustomers = await db.getInactiveCustomers();
  final total = activeCustomers.length + inactiveCustomers.length;

  // Calculate retention and churn rates
  final retentionRate =
      total > 0 ? (activeCustomers.length / total) * 100 : 0.0;
  final churnRate = total > 0 ? (inactiveCustomers.length / total) * 100 : 0.0;

  // Trend analysis: customers activated/deactivated in last 30 days
  final now = DateTime.now();
  final last30Days = now.subtract(Duration(days: 30));
  final newCustomers = activeCustomers
      .where((c) => c.subscriptionStart.isAfter(last30Days))
      .length;
  final lostCustomers =
      inactiveCustomers.where((c) => c.lastModified.isAfter(last30Days)).length;

  return {
    'retentionRate': retentionRate,
    'churnRate': churnRate,
    'newCustomersLast30Days': newCustomers,
    'lostCustomersLast30Days': lostCustomers,
    'activeCount': activeCustomers.length,
    'inactiveCount': inactiveCustomers.length,
  };
});
