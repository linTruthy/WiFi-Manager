import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import '../database/models/plan.dart';
import '../providers/customer_provider.dart';
import '../providers/payment_provider.dart';
import '../services/ad_manager.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/receipt_button.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final AdManager _adManager = AdManager();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  @override
  void initState() {
    super.initState();
    _initializeAds();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd(size: AdSize.mediumRectangle);
    await _adManager.initializeInterstitialAd();
  }

  @override
  void dispose() {
    _showExitInterstitial();
    _searchController.dispose();
    _adManager.dispose();
    super.dispose();
  }

  Future<void> _showExitInterstitial() async {
    await _adManager.showInterstitialAd();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPaymentsAsync = ref.watch(filteredPaymentsProvider);
    final paymentSummaryAsync = ref.watch(paymentSummaryProvider);
    final selectedDateRange = ref.watch(selectedDateRangeProvider);

    return WillPopScope(
      onWillPop: () async {
        await _showExitInterstitial();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () => _selectDateRange(context, ref),
              tooltip: 'Select date range',
            ),
            if (selectedDateRange != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  ref.read(selectedDateRangeProvider.notifier).state = null;
                },
                tooltip: 'Clear date range',
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search by customer name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            // Selected Date Range Display
            if (selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Showing payments from ${DateFormat('MMM d, y').format(selectedDateRange.start)} to ${DateFormat('MMM d, y').format(selectedDateRange.end)}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            Expanded(
              child: filteredPaymentsAsync.when(
                data: (payments) {
                  final filteredPayments = payments.where((payment) {
                    final customerName = payment.customerId.toLowerCase();
                    return customerName.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      final payment = filteredPayments[index];
                      final customerAsync =
                          ref.watch(customerProvider(payment.customerId));
                      return ListTile(
                        leading: _getPlanIcon(payment.planType),
                        title: Text(
                          'UGX ${payment.amount.toStringAsFixed(0)} • ${payment.planType.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: customerAsync.when(
                          data: (customer) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(customer?.name ?? 'Unknown Customer'),
                                  if (customer != null && !customer.isActive)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        '(Inactive)',
                                        style: TextStyle(
                                            color: Colors.red, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '${payment.customerId} • ${DateFormat('MMM d, y').format(payment.paymentDate)}',
                              ),
                            ],
                          ),
                          loading: () => const Text('Loading...'),
                          error: (_, __) => const Text('Unknown Customer'),
                        ),
                        // subtitle: Text(
                        //   '${payment.customerId} • ${DateFormat('MMM d, y').format(payment.paymentDate)}',
                        // ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              payment.isConfirmed
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: payment.isConfirmed
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            ReceiptButton(payment: payment),
                          ],
                        ),
                        onTap: () {
                          // Navigate to payment details screen
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
            // Summary Section
            paymentSummaryAsync.when(
              data: (summary) => Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Summary',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Daily', summary['daily'] ?? 0),
                      _buildSummaryRow('Weekly', summary['weekly'] ?? 0),
                      _buildSummaryRow('Monthly', summary['monthly'] ?? 0),
                      const Divider(),
                      _buildSummaryRow('Total', summary['total'] ?? 0,
                          isTotal: true),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Consumer(
            //   builder: (context, ref, child) {
            //     final dateRange = ref.watch(selectedDateRangeProvider);
            //     if (dateRange == null) return const SizedBox.shrink();
            //     return Padding(
            //       padding: const EdgeInsets.all(8.0),
            //       child: Chip(
            //         label: Text(
            //           '${DateFormat('MMM d').format(dateRange.start)} - '
            //           '${DateFormat('MMM d').format(dateRange.end)}',
            //         ),
            //         onDeleted: () => ref
            //             .read(selectedDateRangeProvider.notifier)
            //             .state = null,
            //       ),
            //     );
            //   },
            // ),
            //   _PaymentSummaryCard(summaryAsync: summaryAsync),
            // Expanded(
            //   child: paymentsAsync.when(
            //     data: (payments) => payments.isEmpty
            //         ? const Center(child: Text('No payments found'))
            //         : ListView.builder(
            //             itemCount: payments.length,
            //             itemBuilder: (context, index) =>
            //                 _PaymentListTile(payment: payments[index]),
            //           ),
            //     loading: () => const Center(child: CircularProgressIndicator()),
            //     error: (error, stack) => Center(child: Text('Error: $error')),
            //   ),
            // ),
            Center(
              child: _adManager.getBannerAdWidget(
                maxWidth: MediaQuery.of(context).size.width,
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'add_payment',
          isExtended: true,
          onPressed: () {
            _showAddPaymentDialog(context);
          },
          tooltip: 'Add Payment',
          label: const Text('Add Payment'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final initialDateRange = ref.read(selectedDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );
    if (picked != null) {
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }

  Icon _getPlanIcon(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return const Icon(Icons.calendar_today, color: Colors.blue);
      case PlanType.weekly:
        return const Icon(Icons.calendar_view_week, color: Colors.green);
      case PlanType.monthly:
        return const Icon(Icons.calendar_view_month, color: Colors.orange);
    }
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text('UGX ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _showAddPaymentDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AddPaymentDialog(),
    );
    if (result == true) {
      await _adManager.showInterstitialAd();
    }
  }
}
