import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../database/models/customer.dart';
import '../providers/customer_provider.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/subscription_provider.dart';
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
  late List<Plan> _plans; // Store the plans fetched from getPlans()
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans(); // Load plans when initializing
    if (widget.customer != null) {
      _selectedCustomerId = widget.customer!.id;
      _selectedPlan = widget.customer!.planType;
      _updateAmount(); // Set default amount based on plan
    }
  }

  // Fetch plans asynchronously and update state
  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);
    _plans = await getPlans();
    if (mounted) {
      setState(() {
        _isLoadingPlans = false;
        _updateAmount();
      });
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
              // Customer Selection
              if (widget.customer == null)
                customersAsync.when(
                  data: (customers) => DropdownButtonFormField<String>(
                    value: _selectedCustomerId,
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                    ),
                    items: customers
                        .map((customer) => DropdownMenuItem(
                              value: customer.id,
                              child: Text(customer.name),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCustomerId = value),
                    validator: (value) =>
                        value == null ? 'Please select a customer' : null,
                    focusNode: FocusNode(), // Ensure keyboard focus
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading customers'),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Customer: ${widget.customer!.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    semanticsLabel:
                        'Selected customer: ${widget.customer!.name}',
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
                      Text(DateFormat('yyyy-MM-dd hh:mm a').format(_startDate)),
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
                  return DropdownMenuItem(value: plan, child: Text(plan.name));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPlan = value;
                      _updateAmount();
                    });
                  }
                },
                focusNode: FocusNode(),
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
                  if (value == null || value.isEmpty)
                    return 'Please enter an amount';
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                focusNode: FocusNode(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
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

    if (pickedDate != null && mounted) {
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

      if (pickedTime != null && mounted) {
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

  // Update amount based on user-configured plan prices
  void _updateAmount() {
    final selectedPlan = _plans.firstWhere(
      (plan) => plan.type == _selectedPlan,
      orElse: () => Plan(type: _selectedPlan, price: 0.0, durationInDays: 1),
    );
    _amountController.text = selectedPlan.price.toStringAsFixed(0);
  }

  DateTime _calculateEndDate(DateTime startDate, PlanType planType) {
    final selectedPlan = _plans.firstWhere(
      (plan) => plan.type == planType,
      orElse: () => Plan(type: planType, price: 0.0, durationInDays: 1),
    );
    return startDate.add(Duration(days: selectedPlan.durationInDays));
  }

  Future<void> _savePayment() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final database = ref.read(databaseProvider);

        // Fetch customer from Firestore
        final customerDoc = await database.firestore
            .collection(database.getUserCollectionPath('customers'))
            .doc(_selectedCustomerId)
            .get();
        if (!customerDoc.exists) throw Exception('Customer not found');
        final customer = Customer.fromJson(customerDoc.id, customerDoc.data()!);

        // Create payment record
        final payment = Payment(
          paymentDate: DateTime.now(),
          amount: double.parse(_amountController.text),
          customerId: _selectedCustomerId!,
          planType: _selectedPlan,
          isConfirmed: true,
        );

        // Update customer subscription and activate if inactive
        customer.subscriptionStart = _startDate;
        customer.subscriptionEnd = _calculateEndDate(_startDate, _selectedPlan);
        customer.planType = _selectedPlan;
        if (!customer.isActive) {
          customer.isActive = true; // Activate the customer
        }

        // Generate WiFi credentials if first payment or reactivating
        final previousPaymentsSnapshot = await database.firestore
            .collection(database.getUserCollectionPath('payments'))
            .where('customerId', isEqualTo: _selectedCustomerId)
            .get();
        final previousPayments = previousPaymentsSnapshot.docs
            .map((doc) => Payment.fromJson(doc.id, doc.data()))
            .toList();
        if (previousPayments.length <= 1 || !customer.isActive) {
          customer.wifiName = Customer.generateWifiName(customer.name);
          customer.currentPassword = Customer.generate();
        }

        // Save to Firestore using a batch for atomicity
        final batch = database.firestore.batch();
        final paymentDoc = database.firestore
            .collection(database.getUserCollectionPath('payments'))
            .doc();
        payment.id = paymentDoc.id;
        batch.set(paymentDoc, payment.toJson());
        batch.set(
          database.firestore
              .collection(database.getUserCollectionPath('customers'))
              .doc(customer.id),
          customer.toJson(),
        );
        await batch.commit();
print('to show ffffffffffffffffffffff');
        if (!mounted) return;

        Navigator.pop(context, true); // Return true to indicate success

        // Invalidate providers to refresh UI
        ref.invalidate(recentPaymentsProvider);
        ref.invalidate(paymentSummaryProvider);
        ref.invalidate(filteredPaymentsProvider);
        ref.invalidate(activeCustomersProvider);
        ref.invalidate(inactiveCustomersProvider); // For reactivation
        ref.invalidate(expiringCustomersProvider);
        ref.invalidate(databaseProvider);
        ref.invalidate(customerProvider);
        ref.invalidate(expiringSubscriptionsProvider);
        ref.invalidate(notificationSchedulerProvider);

        // Schedule notification for the updated subscription
        await SubscriptionNotificationService
            .scheduleSingleExpirationNotification(customer);
print('to show rrrrrrrrrrrrr');
        // Show WiFi credentials dialog
        if (mounted) {
          //&& (previousPayments.length <= 1 || !customer.isActive)) {
          print('to show xxxxxxxxxxx');
          showDialog(
            context: context,
            builder: (context) => _buildWiFiCredentialsDialog(customer),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded successfully')),
          );
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

  Widget _buildWiFiCredentialsDialog(Customer customer) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFF1E1E1E), // Dark theme surface color
      title: Semantics(
        label: 'WiFi Credentials Dialog Title',
        child: const Text(
          'WiFi Access Setup',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introductory Message
            Semantics(
              label: 'Instruction Header',
              child: Text(
                'Set up WiFi access for ${customer.name} with these credentials:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // WiFi Credentials Section
            _buildCredentialField(
              label: 'WiFi Name',
              value: customer.wifiName,
              semanticsLabel: 'WiFi Name for ${customer.name}',
            ),
            const SizedBox(height: 12),
            _buildCredentialField(
              label: 'Password',
              value: customer.currentPassword,
              semanticsLabel: 'WiFi Password for ${customer.name}',
            ),
            const SizedBox(height: 20),

            // Instructions Section
            Semantics(
              label: 'Setup Instructions',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Add to Your Router:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Log in to your router (usually via 192.168.1.1 or 192.168.0.1 in a browser).\n'
                      '2. Go to "Wireless" or "WiFi Settings".\n'
                      '3. Add a new SSID with the WiFi Name above.\n'
                      '4. Set the Password as shown.\n'
                      '5. Save and reboot the router if needed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Semantics(
          label: 'Close WiFi Credentials Dialog',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF1A73E8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialField({
    required String label,
    required String value,
    required String semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Copy $label',
            child: IconButton(
              icon: const Icon(Icons.copy, color: Color(0xFF1A73E8)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard')),
                );
              },
              tooltip: 'Copy $label',
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Plan>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      Plan(
        type: PlanType.daily,
        price: prefs.getDouble('dailyPrice') ?? 1000.0,
        durationInDays: 1,
      ),
      Plan(
        type: PlanType.weekly,
        price: prefs.getDouble('weeklyPrice') ?? 5000.0,
        durationInDays: 7,
      ),
      Plan(
        type: PlanType.monthly,
        price: prefs.getDouble('monthlyPrice') ?? 15000.0,
        durationInDays: 30,
      ),
    ];
  }
}
