import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truthy_wifi_manager/database/models/billing_cycle.dart';
import 'package:truthy_wifi_manager/providers/database_provider.dart';

final billingCyclesProvider = FutureProvider<List<BillingCycle>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getBillingCycles();
});
