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
  bool _isLoading = false;
  String? _errorMessage;
  String _sortCriteria = 'date';
  bool _sortAscending = false;

  @override
  void dispose() {
    _expenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billingCyclesAsync = ref.watch(billingCyclesProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_US', symbol: 'UGX', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Cycles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildInputForm(context),
            Expanded(
              child: billingCyclesAsync.when(
                data: (cycles) => _buildCyclesList(cycles, currencyFormat),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading billing cycles: $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(billingCyclesProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Billing Cycle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track your WiFi costs and income for a specific period',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const Divider(height: 24),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start Date',
                      value: _startDate,
                      onSelected: (date) => setState(() => _startDate = date),
                      icon: Icons.calendar_today,
                      semanticLabel:
                          'Select the start date of this billing cycle',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateField(
                      label: 'End Date',
                      value: _endDate,
                      onSelected: (date) => setState(() => _endDate = date),
                      icon: Icons.calendar_month,
                      semanticLabel:
                          'Select the end date of this billing cycle',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expenseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'WiFi Expense',
                  helperText:
                      'Enter the total cost of WiFi service for this period',
                  prefixIcon: const Icon(Icons.money),
                  prefixText: 'UGX ',
                  border: const OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message:
                        'Enter the total amount paid to your ISP for this billing period',
                    child: const Icon(Icons.info_outline),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the expense amount';
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
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveBillingCycle,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save Billing Cycle'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCyclesList(
      List<BillingCycle> cycles, NumberFormat currencyFormat) {
    if (cycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.post_add,
              size: 64,
              color: Colors.grey.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'No billing cycles yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first billing cycle to track expenses and income',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Sort cycles based on criteria
    cycles = _sortCycles(cycles);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Billing History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    underline: Container(),
                    icon: const Icon(Icons.sort),
                    hint: const Text('Sort by'),
                    value: _sortCriteria,
                    items: const [
                      DropdownMenuItem(
                        value: 'date',
                        child: Text('Date'),
                      ),
                      DropdownMenuItem(
                        value: 'profit',
                        child: Text('Profit'),
                      ),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('Expense'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortCriteria = value;
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(_sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    onPressed: () {
                      setState(() {
                        _sortAscending = !_sortAscending;
                      });
                    },
                    tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: cycles.length,
            itemBuilder: (context, index) {
              final cycle = cycles[index];
              final totalIncome = cycle.customerPayments.values
                  .fold(0.0, (sum, amount) => sum + amount);
              final profit = totalIncome - cycle.wifiExpense;
              final isProfit = profit >= 0;

              // Calculate percentage
              final profitPercentage = cycle.wifiExpense > 0
                  ? (profit / cycle.wifiExpense * 100).abs()
                  : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: InkWell(
                  onTap: () => _showCycleDetails(cycle, currencyFormat),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${DateFormat('MMM d, y').format(cycle.startDate)} - ${DateFormat('MMM d, y').format(cycle.endDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _buildDaysIndicator(cycle),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                'Expense',
                                currencyFormat.format(cycle.wifiExpense),
                                Icons.arrow_downward,
                                Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                'Income',
                                currencyFormat.format(totalIncome),
                                Icons.arrow_upward,
                                Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                isProfit ? 'Profit' : 'Loss',
                                currencyFormat.format(profit.abs()),
                                isProfit
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                isProfit ? Colors.green : Colors.red,
                                suffix: profitPercentage > 0
                                    ? '${profitPercentage.toStringAsFixed(1)}%'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: cycle.customerPayments.isNotEmpty
                              ? totalIncome /
                                  (cycle.wifiExpense * 1.5)
                                      .clamp(1, double.infinity)
                              : 0,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: isProfit ? Colors.green : Colors.red,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDaysIndicator(BillingCycle cycle) {
    final days = cycle.endDate.difference(cycle.startDate).inDays + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_view_day,
            size: 14,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            '$days ${days == 1 ? 'day' : 'days'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color,
      {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 4),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime?) onSelected,
    required IconData icon,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: TextFormField(
        readOnly: true,
        controller: TextEditingController(
          text: value != null ? DateFormat('MMM d, y').format(value) : '',
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          helperText: value == null ? 'Select a date' : null,
        ),
        validator: (value) =>
            value?.isEmpty ?? true ? 'Please select a date' : null,
        onTap: () async {
          // Clear focus to prevent keyboard from showing up
          FocusScope.of(context).unfocus();

          final selectedDate = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
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

          if (selectedDate != null) {
            onSelected(selectedDate);

            // If this is the start date and end date is not set or before start date
            if (label == 'Start Date' &&
                (_endDate == null || _endDate!.isBefore(selectedDate))) {
              // Auto-suggest end date (e.g., end of month or +30 days)
              final endOfMonth = DateTime(
                selectedDate.year,
                selectedDate.month + 1,
                0,
              );
              final suggestedEndDate = endOfMonth.isBefore(DateTime.now())
                  ? endOfMonth
                  : DateTime.now();
              setState(() => _endDate = suggestedEndDate);
            }
          }
        },
      ),
    );
  }

  Future<void> _saveBillingCycle() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        setState(() {
          _errorMessage = 'Please select both start and end dates';
        });
        return;
      }

      if (_endDate!.isBefore(_startDate!)) {
        setState(() {
          _errorMessage = 'End date cannot be before start date';
        });
        return;
      }

      // Confirm before saving
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Billing Cycle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to save this billing cycle?'),
              const SizedBox(height: 16),
              _buildInfoRow('Period',
                  '${DateFormat('MMM d, y').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'),
              _buildInfoRow('WiFi Expense', 'UGX ${_expenseController.text}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAVE'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final database = ref.read(databaseProvider);

        // Fetch payments within the date range
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

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Billing cycle saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reset form
        setState(() {
          _startDate = null;
          _endDate = null;
          _wifiExpense = 0.0;
          _expenseController.clear();
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to save billing cycle: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCycleDetails(
      BillingCycle cycle, NumberFormat currencyFormat) async {
    final database = ref.read(databaseProvider);

    // Show loading dialog while fetching customer details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading details...'),
          ],
        ),
      ),
    );

    // Process customer payment details
    final customerDataFutures =
        cycle.customerPayments.entries.map((entry) async {
      final customerId = entry.key;
      final amount = entry.value;

      // Fetch customer name
      final customerDoc = await database.firestore
          .collection(database.getUserCollectionPath('customers'))
          .doc(customerId)
          .get();

      final customerName = customerDoc.exists
          ? customerDoc.data()!['name'] ?? 'Unknown Customer'
          : 'Unknown Customer';

      return {
        'id': customerId,
        'name': customerName,
        'amount': amount,
      };
    }).toList();

    // Wait for all futures to complete
    final customerData = await Future.wait(customerDataFutures);

    // Sort by amount (highest to lowest)
    customerData.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // Calculate metrics
    final totalIncome =
        cycle.customerPayments.values.fold(0.0, (sum, amount) => sum + amount);
    final profit = totalIncome - cycle.wifiExpense;
    final profitMargin = totalIncome > 0 ? (profit / totalIncome * 100) : 0.0;
    final customerCount = cycle.customerPayments.length;
    final averageRevenue =
        customerCount > 0 ? (totalIncome / customerCount) : 0.0;

    // Close loading dialog
    Navigator.pop(context);

    // Show details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Billing Cycle Details',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMMM d, y').format(cycle.startDate)} - ${DateFormat('MMMM d, y').format(cycle.endDate)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 32),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Expense',
                      currencyFormat.format(cycle.wifiExpense),
                      Icons.trending_down,
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      'Income',
                      currencyFormat.format(totalIncome),
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryCard(
                      profit >= 0 ? 'Profit' : 'Loss',
                      currencyFormat.format(profit.abs()),
                      profit >= 0 ? Icons.check_circle : Icons.cancel,
                      profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Additional Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Profit Margin',
                      '${profitMargin.toStringAsFixed(1)}%',
                      profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricCard(
                      'Customers',
                      customerCount.toString(),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricCard(
                      'Avg. Revenue',
                      currencyFormat.format(averageRevenue),
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Customer Payment List
              const Text(
                'Customer Payments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              customerData.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No customer payments recorded for this period',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: customerData.length,
                      itemBuilder: (context, index) {
                        final customer = customerData[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            child: Text(
                              (customer['name'] as String)[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          title: Text(customer['name'] as String),
                          subtitle: Text('ID: ${customer['id']}'),
                          trailing: Text(
                            currencyFormat.format(customer['amount']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  List<BillingCycle> _sortCycles(List<BillingCycle> cycles) {
    switch (_sortCriteria) {
      case 'date':
        cycles.sort((a, b) => _sortAscending
            ? a.startDate.compareTo(b.startDate)
            : b.startDate.compareTo(a.startDate));
        break;
      case 'profit':
        cycles.sort((a, b) {
          final aProfit = a.customerPayments.values
                  .fold(0.0, (sum, amount) => sum + amount) -
              a.wifiExpense;
          final bProfit = b.customerPayments.values
                  .fold(0.0, (sum, amount) => sum + amount) -
              b.wifiExpense;
          return _sortAscending
              ? aProfit.compareTo(bProfit)
              : bProfit.compareTo(aProfit);
        });
        break;
      case 'expense':
        cycles.sort((a, b) => _sortAscending
            ? a.wifiExpense.compareTo(b.wifiExpense)
            : b.wifiExpense.compareTo(a.wifiExpense));
        break;
      default:
        cycles.sort((a, b) => b.startDate.compareTo(a.startDate));
    }
    return cycles;
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Billing Cycles'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Billing cycles help you track your WiFi expenses and income over a specific period.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'Create Cycle',
                'Set a start and end date, enter your WiFi expense amount, and save to create a new billing cycle.',
              ),
              _buildHelpItem(
                'Customer Payments',
                'All customer payments made within the date range will be automatically included in the billing cycle.',
              ),
              _buildHelpItem(
                'Profit Calculation',
                'Profit is calculated by subtracting your WiFi expense from the total customer payments.',
              ),
              _buildHelpItem(
                'View Details',
                'Tap on any billing cycle to see detailed information about customer payments and financial metrics.',
              ),
            ],
          ),
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

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
