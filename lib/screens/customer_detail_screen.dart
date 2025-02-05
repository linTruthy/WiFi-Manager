import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wifi_manager/screens/referral_stats_screen.dart';

import '../database/models/customer.dart';
import '../widgets/add_payment_dialog.dart';
import 'edit_customer_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysUntilExpiry =
        customer.subscriptionEnd.difference(DateTime.now()).inDays;
    final isExpiring = daysUntilExpiry <= 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ReferralStatsScreen(
                          referrerId: customer.id.toString(),
                        ),
                  ),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditCustomerScreen(customer: customer),
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
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscription expires in ${_formatExpiryTime(customer.subscriptionEnd, daysUntilExpiry)}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => showDialog(
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
                  _buildDetailRow(
                    'Status',
                    customer.isActive ? 'Active' : 'Inactive',
                  ),
                  const Divider(),
                  _buildDetailRow('Plan', customer.planType.name),
                  const Divider(),
                  _buildDetailRow(
                    'Subscription Start',
                    DateFormat(
                      'MMM d, y - hh:mm a',
                    ).format(customer.subscriptionStart),
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Subscription End',
                    _formatExpiryTime(
                      customer.subscriptionEnd,
                      daysUntilExpiry,
                    ),
                  ),
                  _buildDetailRow(
                    '',
                    DateFormat(
                      'MMM d, y - hh:mm a',
                    ).format(customer.subscriptionEnd),
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
                  const Text(
                    'Referral Program',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Your Referral Code', customer.referralCode),
                  const SizedBox(height: 8),
                  const Text(
                    'Share your referral code with friends to earn free subscription days!',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed:
                        () =>
                            _shareReferralCode(context, customer.referralCode),
                    child: const Text('Share Referral Code'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => showDialog(
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
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  String _formatExpiryTime(DateTime subscriptionEnd, int daysUntilExpiry) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);

    if (daysUntilExpiry > 0) {
      // Positive days - standard display
      return DateFormat('MMM d, y').format(subscriptionEnd);
    } else if (difference.inHours.abs() < 24) {
      // Less than a day (hours)
      final hours = difference.inHours.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $hours hour${hours != 1 ? 's' : ''}';
    } else if (difference.inMinutes.abs() < 60) {
      // Less than an hour (minutes)
      final minutes = difference.inMinutes.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $minutes minute${minutes != 1 ? 's' : ''}';
    } else {
      // More than a day past expiration
      final expiredDays = (-daysUntilExpiry).abs();
      return 'Expired $expiredDays day${expiredDays != 1 ? 's' : ''} ago';
    }
  }

  void _shareReferralCode(BuildContext context, String referralCode) {
    final message = 'Join Truthy WiFi using my referral code: $referralCode';
    Share.share(message);
  }
}
