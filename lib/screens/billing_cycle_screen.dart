import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/models/billing_cycle.dart';
import '../database/models/payment.dart';
import '../providers/database_provider.dart';

class BillingCycleScreen extends ConsumerStatefulWidget {
  const BillingCycleScreen({super.key});

  @override
  ConsumerState<BillingCycleScreen> createState() => _BillingCycleScreenState();
}

class _BillingCycleScreenState extends ConsumerState<BillingCycleScreen> {
  DateTimeRange? _selectedRange;
  double _wifiExpense = 0.0;

  @override
  Widget build(BuildContext context) {
    final billingCyclesAsync = ref.watch(billingCyclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Billing Cycles')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _selectDateRange,
                  child: Text(_selectedRange == null
                      ? 'Select Billing Period'
                      : '${DateFormat('MMM d').format(_selectedRange!.start)} - ${DateFormat('MMM d').format(_selectedRange!.end)}'),
                ),
                TextField(
                  decoration:
                      const InputDecoration(labelText: 'WiFi Expense (UGX)'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      _wifiExpense = double.tryParse(value) ?? 0.0,
                ),
                ElevatedButton(
                  onPressed: _saveBillingCycle,
                  child: const Text('Save Billing Cycle'),
                ),
              ],
            ),
          ),
          Expanded(
            child: billingCyclesAsync.when(
              data: (cycles) => ListView.builder(
                itemCount: cycles.length,
                itemBuilder: (context, index) {
                  final cycle = cycles[index];
                  final totalIncome = cycle.customerPayments.values
                      .fold(0.0, (sum, amount) => sum + amount);
                  final profit = totalIncome - cycle.wifiExpense;
                  return Card(
                    child: ListTile(
                      title: Text(
                          '${DateFormat('MMM d, y').format(cycle.startDate)} - ${DateFormat('MMM d, y').format(cycle.endDate)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Expense: UGX ${cycle.wifiExpense.toStringAsFixed(0)}'),
                          Text('Income: UGX ${totalIncome.toStringAsFixed(0)}'),
                          Text('Profit: UGX ${profit.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color:
                                      profit >= 0 ? Colors.green : Colors.red)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (range != null) setState(() => _selectedRange = range);
  }

  Future<void> _saveBillingCycle() async {
    if (_selectedRange == null) return;

    final database = ref.read(databaseProvider);
    final paymentsSnapshot = await database.firestore
        .collection(database.getUserCollectionPath('payments'))
        .where('paymentDate',
            isGreaterThanOrEqualTo: _selectedRange!.start.toIso8601String())
        .where('paymentDate',
            isLessThanOrEqualTo: _selectedRange!.end.toIso8601String())
        .get();

    final payments = paymentsSnapshot.docs
        .map((doc) => Payment.fromJson(doc.id, doc.data()))
        .toList();
    final customerPayments =
        Map.fromEntries(payments.map((p) => MapEntry(p.customerId, p.amount)));

    final cycle = BillingCycle(
      startDate: _selectedRange!.start,
      endDate: _selectedRange!.end,
      wifiExpense: _wifiExpense,
      customerPayments: customerPayments,
    );

    await database.saveBillingCycle(cycle);
    ref.invalidate(billingCyclesProvider);
  }
}

final billingCyclesProvider = FutureProvider<List<BillingCycle>>((ref) async {
  final database = ref.watch(databaseProvider);
  return database.getBillingCycles();
});
