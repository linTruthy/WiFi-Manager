import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/models/customer.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../providers/database_provider.dart';

class AddPaymentDialog extends ConsumerStatefulWidget {
  final Customer? customer;

  const AddPaymentDialog({super.key, this.customer});

  @override
  ConsumerState<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _notesController = TextEditingController();

  Customer? _selectedCustomer;
  PlanType _selectedPlan = PlanType.monthly;
  DateTime _paymentDate = DateTime.now();
  bool _isConfirmed = true;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _customAmount = false;

  List<Customer> _filteredCustomers = [];
  List<Customer> _allCustomers = [];

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.customer;
    _loadCustomers();

    // Set default plan
    if (_selectedCustomer != null) {
      _selectedPlan = _selectedCustomer!.planType;
      _updateAmount();
    }

    _paymentDateController.text = DateFormat('MMMM d, y').format(_paymentDate);

    _searchController.addListener(() {
      _filterCustomers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _paymentDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final database = ref.read(databaseProvider);
      final customers = await database.getActiveCustomers();

      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load customers: $e')),
      );
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _allCustomers;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((customer) {
        return customer.name.toLowerCase().contains(lowercaseQuery) ||
            customer.contact.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  void _updateAmount() {
    if (_customAmount) return;

    double amount = 0.0;
    switch (_selectedPlan) {
      case PlanType.daily:
        amount = 2000.0;
        break;
      case PlanType.weekly:
        amount = 10000.0;
        break;
      case PlanType.monthly:
        amount = 35000.0;
        break;
    }

    _amountController.text = amount.toString();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(Duration(days: 30)),
      lastDate: DateTime.now().add(Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
        _paymentDateController.text =
            DateFormat('MMMM d, y').format(_paymentDate);
      });
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final database = ref.read(databaseProvider);
      final amount = double.parse(_amountController.text);

      // Calculate new subscription end date
      final oldEnd = _selectedCustomer!.subscriptionEnd;
      DateTime newEnd;

      // If subscription has already expired, start from now
      final now = DateTime.now();
      final startDate = oldEnd.isBefore(now) ? now : oldEnd;

      switch (_selectedPlan) {
        case PlanType.daily:
          newEnd = startDate.add(Duration(days: 1));
          break;
        case PlanType.weekly:
          newEnd = startDate.add(Duration(days: 7));
          break;
        case PlanType.monthly:
          newEnd = startDate.add(Duration(days: 30));
          break;
      }

      // Create payment
      final payment = Payment(
        paymentDate: _paymentDate,
        amount: amount,
        customerId: _selectedCustomer!.id,
        planType: _selectedPlan,
        isConfirmed: _isConfirmed,
      );

      // Update customer subscription end date
      final updatedCustomer = _selectedCustomer!.copyWith(
        subscriptionEnd: newEnd,
        isActive: true,
      );

      // Save both changes
      final batch = database.firestore.batch();

      // Save payment
      final paymentRef = database.firestore
          .collection(database.getUserCollectionPath('payments'))
          .doc();
      batch.set(paymentRef, payment.toJson());

      // Update customer
      final customerRef = database.firestore
          .collection(database.getUserCollectionPath('customers'))
          .doc(_selectedCustomer!.id);
      batch.set(customerRef, updatedCustomer.toJson());

      await batch.commit();

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      title: Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Selection
            Text(
              'Customer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 8),

            _selectedCustomer == null
                ? _buildCustomerSearch(theme)
                : _buildSelectedCustomer(theme),

            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),

            // Plan Selection
            Text(
              'Subscription Plan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 8),
            _buildPlanSelection(theme),

            SizedBox(height: 16),

            // Amount
            Row(
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Spacer(),
                Semantics(
                  label: 'Toggle custom amount',
                  child: Row(
                    children: [
                      Text(
                        'Custom Amount',
                        style: TextStyle(fontSize: 12),
                      ),
                      Switch(
                        value: _customAmount,
                        onChanged: (value) {
                          setState(() {
                            _customAmount = value;
                            if (!value) _updateAmount();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                hintText: 'Enter payment amount',
                prefixText: 'UGX ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabled: _customAmount,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),

            SizedBox(height: 16),

            // Payment Date
            Text(
              'Payment Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 8),
            Semantics(
              label: 'Select payment date',
              button: true,
              child: InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_paymentDateController.text),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Payment Status
            Text(
              'Payment Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 8),
            Semantics(
              label: 'Set payment as confirmed',
              child: SwitchListTile(
                title: Text('Mark as Confirmed'),
                subtitle: Text(
                  _isConfirmed
                      ? 'Payment is confirmed and processed'
                      : 'Payment is pending confirmation',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isConfirmed,
                onChanged: (value) {
                  setState(() {
                    _isConfirmed = value;
                  });
                },
                secondary: Icon(
                  _isConfirmed ? Icons.check_circle : Icons.pending,
                  color: _isConfirmed ? Colors.green : Colors.orange,
                ),
              ),
            ),

            SizedBox(height: 16),

            // Notes (Optional)
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any additional notes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),

            if (_selectedCustomer != null) ...[
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 16),

              // Subscription Update Preview
              Text(
                'Subscription Update Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: 8),
              _buildSubscriptionPreview(theme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePayment,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('SAVE'),
        ),
      ],
    );
  }

  Widget _buildCustomerSearch(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search customers...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _isSearching = value.isNotEmpty;
            });
          },
        ),
        if (_isSearching) ...[
          SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxHeight: 200,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filteredCustomers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No customers found for "${_searchController.text}"',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.2),
                          child: Text(customer.name[0].toUpperCase()),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(customer.contact),
                        onTap: () {
                          setState(() {
                            _selectedCustomer = customer;
                            _selectedPlan = customer.planType;
                            _isSearching = false;
                            _searchController.clear();
                            _updateAmount();
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedCustomer(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Text(_selectedCustomer!.name[0].toUpperCase()),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomer!.name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  _selectedCustomer!.contact,
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _selectedCustomer!.subscriptionEnd
                              .isBefore(DateTime.now())
                          ? Icons.warning
                          : Icons.check_circle,
                      size: 12,
                      color: _selectedCustomer!.subscriptionEnd
                              .isBefore(DateTime.now())
                          ? Colors.orange
                          : Colors.green,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Expires: ${DateFormat('MMM d, y').format(_selectedCustomer!.subscriptionEnd)}',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedCustomer = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelection(ThemeData theme) {
    return Row(
      children: [
        _buildPlanOption(
          theme,
          PlanType.daily,
          'Daily',
          'UGX 2,000',
          Icons.calendar_today,
          Colors.blue,
        ),
        SizedBox(width: 8),
        _buildPlanOption(
          theme,
          PlanType.weekly,
          'Weekly',
          'UGX 10,000',
          Icons.calendar_view_week,
          Colors.green,
        ),
        SizedBox(width: 8),
        _buildPlanOption(
          theme,
          PlanType.monthly,
          'Monthly',
          'UGX 35,000',
          Icons.calendar_view_month,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPlanOption(
    ThemeData theme,
    PlanType planType,
    String label,
    String price,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedPlan == planType;

    return Expanded(
      child: Semantics(
        label: 'Select $label plan',
        selected: isSelected,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPlan = planType;
              _updateAmount();
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : theme.cardColor,
              border: Border.all(
                color: isSelected ? color : theme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : theme.iconTheme.color,
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionPreview(ThemeData theme) {
    // Calculate new end date
    final oldEnd = _selectedCustomer!.subscriptionEnd;
    final now = DateTime.now();
    final startDate = oldEnd.isBefore(now) ? now : oldEnd;

    DateTime newEnd;
    switch (_selectedPlan) {
      case PlanType.daily:
        newEnd = startDate.add(Duration(days: 1));
        break;
      case PlanType.weekly:
        newEnd = startDate.add(Duration(days: 7));
        break;
      case PlanType.monthly:
        newEnd = startDate.add(Duration(days: 30));
        break;
    }

    final isExpired = oldEnd.isBefore(now);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpired ? Icons.refresh : Icons.update,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: 8),
              Text(
                isExpired
                    ? 'Reactivating Subscription'
                    : 'Extending Subscription',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current End Date',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, y').format(oldEnd),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.red : null,
                        decoration:
                            isExpired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isExpired)
                      Text(
                        'Expired',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'New End Date',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, y').format(newEnd),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '(${newEnd.difference(now).inDays} days)',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
