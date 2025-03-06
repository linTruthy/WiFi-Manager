import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:truthy_wifi_manager/providers/billing_cycles_provider.dart';
import '../database/models/billing_cycle.dart';
import '../database/models/payment.dart';
import '../providers/database_provider.dart';

class BillingCycleScreen extends ConsumerStatefulWidget {
  const BillingCycleScreen({super.key});

  @override
  ConsumerState<BillingCycleScreen> createState() => _BillingCycleScreenState();
}

class _BillingCycleScreenState extends ConsumerState<BillingCycleScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  double _wifiExpense = 0.0;
  final _expenseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final billingCyclesAsync = ref.watch(billingCyclesProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_US', symbol: 'UGX', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Billing Cycles')),
      body: Column(
        children: [
          // Input Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildDateField(
                      'Start Date', _startDate, (date) => _startDate = date),
                  const SizedBox(height: 16),
                  _buildDateField(
                      'End Date', _endDate, (date) => _endDate = date),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _expenseController,
                    decoration: const InputDecoration(
                      labelText: 'WiFi Expense',
                      prefixText: 'UGX ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the expense';
                      }
                      final number = double.tryParse(value);
                      if (number == null || number < 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                    onChanged: (value) =>
                        _wifiExpense = double.tryParse(value) ?? 0.0,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    label: 'Save billing cycle',
                    child: ElevatedButton(
                      onPressed: _saveBillingCycle,
                      child: const Text('Save Billing Cycle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // List Section
          Expanded(
            child: billingCyclesAsync.when(
              data: (cycles) => ListView.builder(
                itemCount: cycles.length,
                itemBuilder: (context, index) {
                  final cycle = cycles[index];
                  final totalIncome = cycle.customerPayments.values
                      .fold(0.0, (sum, amount) => sum + amount);
                  final profit = totalIncome - cycle.wifiExpense;
                  return Semantics(
                    label:
                        'Billing cycle from ${DateFormat('MMM d, y').format(cycle.startDate)} to ${DateFormat('MMM d, y').format(cycle.endDate)}, Expense: ${currencyFormat.format(cycle.wifiExpense)}, Income: ${currencyFormat.format(totalIncome)}, Profit: ${currencyFormat.format(profit)}',
                    child: Card(
                      child: ListTile(
                        title: Text(
                            '${DateFormat('MMM d, y').format(cycle.startDate)} - ${DateFormat('MMM d, y').format(cycle.endDate)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Expense: ${currencyFormat.format(cycle.wifiExpense)}'),
                            Text(
                                'Income: ${currencyFormat.format(totalIncome)}'),
                            Text(
                              'Profit: ${currencyFormat.format(profit)}',
                              style: TextStyle(
                                  color:
                                      profit >= 0 ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
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

  Widget _buildDateField(
      String label, DateTime? date, Function(DateTime?) onDateSelected) {
    return Semantics(
      label: 'Select $label'.toLowerCase(),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        controller: TextEditingController(
          text: date != null ? DateFormat('MMM d, y').format(date) : '',
        ),
        onTap: () async {
          final selectedDate = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (selectedDate != null) {
            setState(() {
              onDateSelected(selectedDate);
            });
          }
        },
      ),
    );
  }

  Future<void> _saveBillingCycle() async {
    if (_startDate == null ||
        _endDate == null ||
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select valid start and end dates')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final database = ref.read(databaseProvider);
      final paymentsSnapshot = await database.firestore
          .collection(database.getUserCollectionPath('payments'))
          .where('paymentDate',
              isGreaterThanOrEqualTo: _startDate!.toIso8601String())
          .where('paymentDate',
              isLessThanOrEqualTo: _endDate!.toIso8601String())
          .get();
      final payments = paymentsSnapshot.docs
          .map((doc) => Payment.fromJson(doc.id, doc.data()))
          .toList();
      final customerPayments = Map.fromEntries(
          payments.map((p) => MapEntry(p.customerId, p.amount)));
      final cycle = BillingCycle(
        startDate: _startDate!,
        endDate: _endDate!,
        wifiExpense: _wifiExpense,
        customerPayments: customerPayments,
      );
      await database.saveBillingCycle(cycle);
      ref.invalidate(billingCyclesProvider);
      setState(() {
        _startDate = null;
        _endDate = null;
        _wifiExpense = 0.0;
        _expenseController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing cycle saved successfully')),
      );
    }
  }
}
