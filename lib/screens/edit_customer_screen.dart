import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/customer.dart';
import '../database/models/plan.dart';
import '../providers/customer_provider.dart';
import '../providers/database_provider.dart';

class EditCustomerScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  ConsumerState<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends ConsumerState<EditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _wifiNameController;
  late TextEditingController _passwordController;
  late bool _isActive;
  late PlanType _selectedPlan;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _contactController = TextEditingController(text: widget.customer.contact);
    _wifiNameController = TextEditingController(text: widget.customer.wifiName);
    _passwordController = TextEditingController(
      text: widget.customer.currentPassword,
    );
    _isActive = widget.customer.isActive;
    _selectedPlan = widget.customer.planType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _wifiNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Customer'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveCustomer),
        ],
      ),
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
            TextFormField(
              controller: _wifiNameController,
              decoration: const InputDecoration(
                labelText: 'WiFi Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter WiFi name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.wifi_password),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter password';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active Customer'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
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
                  setState(() => _selectedPlan = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedCustomer = Customer(
        name: _nameController.text,
        contact: _contactController.text,
        isActive: _isActive,
        wifiName: _wifiNameController.text,
        currentPassword: _passwordController.text,
        subscriptionStart: widget.customer.subscriptionStart,
        subscriptionEnd: widget.customer.subscriptionEnd,
        planType: _selectedPlan,
      )..id = widget.customer.id;

      try {
        await ref.read(databaseProvider).saveCustomer(updatedCustomer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer updated successfully')),
          );
          Navigator.pop(context);
          ref.invalidate(activeCustomersProvider);
          ref.invalidate(inactiveCustomersProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating customer: $e')),
          );
        }
      }
    }
  }
}
