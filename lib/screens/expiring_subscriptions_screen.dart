import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import '../database/models/customer.dart';
import '../providers/subscription_provider.dart';

class ExpiringSubscriptionsScreen extends ConsumerWidget {
  const ExpiringSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expiring Subscriptions')),
      body: expiringSubscriptions.when(
        data:
            (customers) =>
                customers.isEmpty
                    ? const Center(child: Text('No expiring subscriptions'))
                    : ListView.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        final daysUntilExpiry =
                            customer.subscriptionEnd
                                .difference(DateTime.now())
                                .inDays;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getExpiryColor(daysUntilExpiry),
                            child: Text(
                              daysUntilExpiry.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: Text(
                            'Expires: ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}\n'
                            'Plan: ${customer.planType.name}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.phone),
                                onPressed: () => _makeCall(customer.contact),
                              ),
                              IconButton(
                                icon: const Icon(Icons.message),
                                onPressed:
                                    () => _sendMessage(
                                      customer.contact,
                                      context,
                                      daysUntilExpiry,
                                    ),
                              ),
                            ],
                          ),
                          onTap:
                              () => _showRenewalDialog(context, ref, customer),
                        );
                      },
                    ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Color _getExpiryColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 2) return Colors.orange;
    return Colors.yellow.shade700;
  }

  Future<void> _makeCall(String contact) async {
    final url = Uri.parse('tel:$contact');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _sendMessage(
    String contact,
    BuildContext context,
    int daysUntilExpiry,
  ) async {
    final messageOptions = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Send Message'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.message),
                  title: const Text('SMS'),
                  onTap: () => Navigator.pop(context, 'sms'),
                ),
                ListTile(
                  leading: const Icon(Icons.whatshot),
                  title: const Text('WhatsApp Business'),
                  onTap: () => Navigator.pop(context, 'whatsapp'),
                ),
              ],
            ),
          ),
    );

    if (messageOptions == null) return;
    String daysleftString =
        daysUntilExpiry <= 0 ? 'TODAY ' : 'in $daysUntilExpiry days';
    final message = Uri.encodeComponent(
      'Dear valued customer, this is a reminder that your WiFi subscription '
      'is due for renewal. Please renew to avoid service interruption. '
      'Your subscription will expire $daysleftString'
      'Thank you for your continued support.',
    );

    final url =
        messageOptions == 'whatsapp'
            ? Uri.parse(
              'https://wa.me/${contact.replaceAll(RegExp(r'[^0-9]'), '')}?text=$message',
            )
            : Uri.parse('sms:$contact?body=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _showRenewalDialog(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Renew Subscription'),
            content: Text(
              'Renew ${customer.name}\'s ${customer.planType.name} plan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/payments',
                    arguments: customer,
                  );
                },
                child: const Text('RENEW'),
              ),
            ],
          ),
    );
  }
}
