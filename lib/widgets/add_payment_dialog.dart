import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../database/models/customer.dart';
import '../database/models/sync_status.dart';
import '../providers/customer_provider.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/syncing_provider.dart';
import '../services/subscription_notification_service.dart';

class AddPaymentDialog extends ConsumerStatefulWidget {
  final Customer? customer; // Optional pre-selected customer
  const AddPaymentDialog({super.key, this.customer});

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
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _selectedCustomerId = widget.customer!.id.toString();
      _selectedPlan = widget.customer!.planType;
      _updateAmount(); // Set default amount based on plan
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

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
              if (widget.customer ==
                  null) // Show dropdown only if no customer provided
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
                    onChanged: (value) =>
                        setState(() => _selectedCustomerId = value),
                    validator: (value) =>
                        value == null ? 'Please select a customer' : null,
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading customers'),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Customer: ${widget.customer!.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date and Time',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd hh:mm a').format(_startDate),
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
                  prefixText: 'UGX ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
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
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 14)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startDate),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _startDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

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

  Future<void> _savePayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final database = ref.read(databaseProvider);
        final isar = await database.db;
        await isar.writeTxn(() async {
          final customer =
              await isar.customers.get(int.parse(_selectedCustomerId!));
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
          await isar.syncStatus.put(
            SyncStatus(
              entityId: payment.id,
              entityType: 'payment',
              operation: 'save',
              timestamp: DateTime.now(),
            ),
          );
          await database.pushPayment(payment);

          // Update customer subscription and activate if inactive
          customer.subscriptionStart = _startDate;
          customer.subscriptionEnd =
              _calculateEndDate(_startDate, _selectedPlan);
          customer.planType = _selectedPlan;
          if (!customer.isActive) {
            customer.isActive = true; // Activate the customer
          }

          // Generate WiFi credentials if first payment or reactivating
          final previousPayments = await isar.payments
              .filter()
              .customerIdEqualTo(_selectedCustomerId!)
              .findAll();
          if (previousPayments.length <= 1 || !customer.isActive) {
            customer.wifiName = Customer.generateWifiName(customer.name);
            customer.currentPassword = Customer.generate();
          }

          await isar.customers.put(customer);
          await isar.syncStatus.put(
            SyncStatus(
              entityId: customer.id,
              entityType: 'customer',
              operation: 'save',
              timestamp: DateTime.now(),
            ),
          );
          await database.pushCustomer(customer);
        });

        if (mounted) {
          final customer =
              await isar.customers.get(int.parse(_selectedCustomerId!));
          Navigator.pop(context, true); // Return true to indicate success
          // Invalidate providers to refresh UI
          ref.invalidate(recentPaymentsProvider);
          ref.invalidate(paymentSummaryProvider);
          ref.invalidate(filteredPaymentsProvider);
          ref.invalidate(activeCustomersProvider);
          ref.invalidate(inactiveCustomersProvider); // For reactivation
          ref.invalidate(expiringCustomersProvider);
          ref.invalidate(syncingProvider);
          ref.invalidate(databaseProvider);
          ref.invalidate(customerProvider);
          ref.invalidate(expiringSubscriptionsProvider);
          ref.invalidate(notificationSchedulerProvider);

          if (customer != null) {
            // Schedule notification for the updated subscription
            await SubscriptionNotificationService
                .scheduleExpirationNotification(customer);

            // Show WiFi credentials dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
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
              content:
                  SelectableText('Error recording payment: $e | $stackTrace'),
              duration: const Duration(minutes: 3),
            ),
          );
        }
      }
    }
  }
}
