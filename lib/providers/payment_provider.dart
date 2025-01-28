import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:riverpod/riverpod.dart';

import '../database/models/payment.dart';
import '../database/models/plan.dart';
import 'database_provider.dart';

final selectedDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final filteredPaymentsProvider = FutureProvider<List<Payment>>((ref) async {
  final database = ref.watch(databaseProvider);
  final dateRange = ref.watch(selectedDateRangeProvider);

  if (dateRange == null) {
    return database.getRecentPayments();
  }

  final isar = await database.db;
  return isar.payments
      .filter()
      .paymentDateBetween(dateRange.start, dateRange.end)
      .findAll();
});

final paymentSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final payments = await ref.watch(filteredPaymentsProvider.future);
  return {
    'daily': payments
        .where((p) => p.planType == PlanType.daily)
        .fold(0, (sum, p) => sum + p.amount),
    'weekly': payments
        .where((p) => p.planType == PlanType.weekly)
        .fold(0, (sum, p) => sum + p.amount),
    'monthly': payments
        .where((p) => p.planType == PlanType.monthly)
        .fold(0, (sum, p) => sum + p.amount),
    'total': payments.fold(0, (sum, p) => sum + p.amount),
  };
});
