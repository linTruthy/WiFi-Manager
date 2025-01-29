import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/customer.dart';
import '../database/models/plan.dart';
import '../providers/database_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  PlanType _selectedPlan = PlanType.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter contact info';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlanType>(
              value: _selectedPlan,
              decoration: const InputDecoration(
                labelText: 'Plan',
                border: OutlineInputBorder(),
              ),
              items:
                  PlanType.values.map((plan) {
                    return DropdownMenuItem(
                      value: plan,
                      child: Text(plan.name),
                    );
                  }).toList(),
              onChanged: (PlanType? value) {
                if (value != null) {
                  setState(() {
                    _selectedPlan = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCustomer,
              child: const Text('Save Customer'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final customer = Customer(
        wifiName: '',
        name: _nameController.text,
        contact: _contactController.text,
        isActive: true,
        currentPassword: _generatePassword(),
        subscriptionStart: DateTime.now(),
        subscriptionEnd: _calculateEndDate(),
        planType: _selectedPlan,
      );

      try {
        await ref.read(databaseProvider).saveCustomer(customer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer saved successfully')),
          );
          Navigator.pop(context);
          ref.invalidate(activeCustomersProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving customer: $e')));
        }
      }
    }
  }

  String _generatePassword() {
    // Implement your password generation logic here
    return 'temp-pass-${Random().nextInt(9999)}';
  }

  DateTime _calculateEndDate() {
    switch (_selectedPlan) {
      case PlanType.daily:
        return DateTime.now().add(const Duration(days: 1));
      case PlanType.weekly:
        return DateTime.now().add(const Duration(days: 7));
      case PlanType.monthly:
        return DateTime.now().add(const Duration(days: 30));
    }
  }
}
