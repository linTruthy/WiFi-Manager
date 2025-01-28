// widgets/add_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../providers/database_provider.dart';


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

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(activeCustomersProvider);

    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customersAsync.when(
              data: (customers) => DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  border: OutlineInputBorder(),
                ),
                items: customers.map((customer) {
                  return DropdownMenuItem(
                    value: customer.id.toString(),
                    child: Text(customer.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCustomerId = value),
                validator: (value) =>
                    value == null ? 'Please select a customer' : null,
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading customers'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlanType>(
              value: _selectedPlan,
              decoration: const InputDecoration(
                labelText: 'Plan Type',
                border: OutlineInputBorder(),
              ),
              items: PlanType.values.map((plan) {
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
                prefixText: '\$',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _savePayment,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _updateAmount() {
    // You could implement automatic amount filling based on plan type
    switch (_selectedPlan) {
      case PlanType.daily:
        _amountController.text = '5.00';
        break;
      case PlanType.weekly:
        _amountController.text = '25.00';
        break;
      case PlanType.monthly:
        _amountController.text = '80.00';
        break;
    }
  }

  void _savePayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      final payment = Payment(
        paymentDate: DateTime.now(),
        amount: double.parse(_amountController.text),
        customerId: _selectedCustomerId!,
        planType: _selectedPlan,
        isConfirmed: true,
      );

      try {
        await ref.read(databaseProvider).savePayment(payment);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error recording payment: $e')),
          );
        }
      }
    }
  }
}