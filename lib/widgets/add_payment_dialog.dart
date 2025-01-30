import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../providers/payment_provider.dart';

class AddPaymentDialog extends ConsumerStatefulWidget {
  const AddPaymentDialog({super.key});

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  PlanType _selectedPlan = PlanType.monthly;
  final _amountController = TextEditingController();
  DateTime _startDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(activeCustomersProvider);

    return AlertDialog(
      title: const Text('Record Payment'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              customersAsync.when(
                data:
                    (customers) => DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          customers.map((customer) {
                            return DropdownMenuItem(
                              value: customer.id.toString(),
                              child: Text(customer.name),
                            );
                          }).toList(),
                      onChanged:
                          (value) =>
                              setState(() => _selectedCustomerId = value),
                      validator:
                          (value) =>
                              value == null ? 'Please select a customer' : null,
                    ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Error loading customers'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PlanType>(
                value: _selectedPlan,
                decoration: const InputDecoration(
                  labelText: 'Plan Type',
                  border: OutlineInputBorder(),
                ),
                items:
                    PlanType.values.map((plan) {
                      return DropdownMenuItem(
                        value: plan,
                        child: Text(plan.name),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPlan = value);
                    _updateAmount();
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: 'UGX',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _savePayment, child: const Text('Save')),
      ],
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // String _generatePassword() {
  //   const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  //   final random = DateTime.now().millisecondsSinceEpoch;
  //   final password =
  //       List.generate(6, (index) {
  //         return chars[random % chars.length];
  //       }).join();
  //   return password;
  // }

  void _updateAmount() {
    switch (_selectedPlan) {
      case PlanType.daily:
        _amountController.text = '2000';
        break;
      case PlanType.weekly:
        _amountController.text = '10000';
        break;
      case PlanType.monthly:
        _amountController.text = '35000';
        break;
    }
  }

  DateTime _calculateEndDate(DateTime startDate, PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return startDate.add(const Duration(days: 1));
      case PlanType.weekly:
        return startDate.add(const Duration(days: 7));
      case PlanType.monthly:
        return startDate.add(const Duration(days: 30));
    }
  }

  void _savePayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final isar = await ref.read(databaseProvider).db;
        await isar.writeTxn(() async {
          final customer = await isar.customers.get(
            int.parse(_selectedCustomerId!),
          );
          if (customer == null) throw Exception('Customer not found');

          // Create payment record
          final payment = Payment(
            paymentDate: DateTime.now(),
            amount: double.parse(_amountController.text),
            customerId: _selectedCustomerId!,
            planType: _selectedPlan,
            isConfirmed: true,
          );
          await isar.payments.put(payment);

          // Update customer subscription details
          customer.subscriptionStart = _startDate;
          customer.subscriptionEnd = _calculateEndDate(
            _startDate,
            _selectedPlan,
          );
          customer.planType = _selectedPlan;

          // Generate WiFi credentials if this is the first subscription
          final previousPayments =
              await isar.payments
                  .filter()
                  .customerIdEqualTo(_selectedCustomerId!)
                  .findAll();

          if (previousPayments.length <= 1) {
            // Including the payment we just created
            customer.wifiName = Customer.generateWifiName(customer.name);
            customer.currentPassword = Customer.generate();
          }

          await isar.customers.put(customer);
        });

        if (mounted) {
          Navigator.pop(context);
          ref.invalidate(recentPaymentsProvider);
          ref.invalidate(paymentSummaryProvider);
          ref.invalidate(filteredPaymentsProvider);
          ref.invalidate(activeCustomersProvider);
          ref.invalidate(expiringCustomersProvider);

          // Show WiFi credentials in a dialog
          final customer = await isar.customers.get(
            int.parse(_selectedCustomerId!),
          );
          if (customer != null) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('WiFi Credentials'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText('WiFi Name: ${customer.wifiName}'),
                        const SizedBox(height: 8),
                        SelectableText('Password: ${customer.currentPassword}'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
          }
        }
      } catch (e, stackTrace) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText(
                'Error recording payment: $e | $stackTrace',
              ),
              duration: Duration(minutes: 3),
            ),
          );
        }
      }
    }
  }
}
