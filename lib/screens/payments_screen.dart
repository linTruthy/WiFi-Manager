import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../database/models/payment.dart';
import '../providers/customer_provider.dart';
import '../providers/payment_provider.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/receipt_button.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(filteredPaymentsProvider);
    final summaryAsync = ref.watch(paymentSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _showDateRangePicker(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPaymentDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final dateRange = ref.watch(selectedDateRangeProvider);
              if (dateRange == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  label: Text(
                    '${DateFormat('MMM d').format(dateRange.start)} - '
                    '${DateFormat('MMM d').format(dateRange.end)}',
                  ),
                  onDeleted:
                      () =>
                          ref.read(selectedDateRangeProvider.notifier).state =
                              null,
                ),
              );
            },
          ),
          _PaymentSummaryCard(summaryAsync: summaryAsync),
          Expanded(
            child: paymentsAsync.when(
              data:
                  (payments) =>
                      payments.isEmpty
                          ? const Center(child: Text('No payments found'))
                          : ListView.builder(
                            itemCount: payments.length,
                            itemBuilder:
                                (context, index) =>
                                    _PaymentListTile(payment: payments[index]),
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker(BuildContext context, WidgetRef ref) async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
    );

    if (dateRange != null) {
      ref.read(selectedDateRangeProvider.notifier).state = dateRange;
    }
  }

  Future<void> _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    return showDialog(
      context: context,
      builder: (context) => const AddPaymentDialog(),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final AsyncValue<Map<String, double>> summaryAsync;

  const _PaymentSummaryCard({required this.summaryAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          data:
              (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue: UGX ${summary['total']?.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  _SummaryRow(
                    title: 'Daily Plans:',
                    amount: summary['daily'] ?? 0,
                  ),
                  _SummaryRow(
                    title: 'Weekly Plans:',
                    amount: summary['weekly'] ?? 0,
                  ),
                  _SummaryRow(
                    title: 'Monthly Plans:',
                    amount: summary['monthly'] ?? 0,
                  ),
                ],
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final double amount;

  const _SummaryRow({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(title), Text('UGX ${amount.toStringAsFixed(0)}')],
      ),
    );
  }
}

class _PaymentListTile extends ConsumerWidget {
  final Payment payment;

  const _PaymentListTile({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerProvider(payment.customerId));

    return ListTile(
      leading: Icon(
        payment.isConfirmed ? Icons.check_circle : Icons.pending,
        color: payment.isConfirmed ? Colors.green : Colors.orange,
      ),
      title: customerAsync.when(
        data: (customer) => Text(customer!.name),
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('Unknown Customer'),
      ),
      subtitle: Text(
        '${payment.planType.name} - ${DateFormat('MMM d, y').format(payment.paymentDate)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'UGX ${payment.amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ReceiptButton(payment: payment),
        ],
      ),
    );
  }
}
