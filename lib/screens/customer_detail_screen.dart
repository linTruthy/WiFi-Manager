import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';


import '../database/models/customer.dart';
import '../widgets/add_payment_dialog.dart';
import 'edit_customer_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysUntilExpiry = customer.subscriptionEnd.difference(DateTime.now()).inDays;
    final isExpiring = daysUntilExpiry <= 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditCustomerScreen(customer: customer),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isExpiring)
            Card(
              color: Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscription expires in $daysUntilExpiry days',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => const AddPaymentDialog(),
                      ),
                      child: const Text('RENEW'),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Contact', customer.contact),
                  const Divider(),
                  _buildDetailRow('WiFi Name', customer.wifiName),
                  const Divider(),
                  _buildDetailRow('Password', customer.currentPassword),
                  const Divider(),
                  _buildDetailRow('Status', customer.isActive ? 'Active' : 'Inactive'),
                  const Divider(),
                  _buildDetailRow('Plan', customer.planType.name),
                  const Divider(),
                  _buildDetailRow(
                    'Subscription Start',
                    DateFormat('MMM d, y').format(customer.subscriptionStart),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Subscription End',
                    DateFormat('MMM d, y').format(customer.subscriptionEnd),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddPaymentDialog(),
        ),
        icon: const Icon(Icons.payment),
        label: const Text('Add Payment'),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}