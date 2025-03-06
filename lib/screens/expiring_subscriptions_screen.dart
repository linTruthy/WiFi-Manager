import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/models/customer.dart';
import '../providers/subscription_provider.dart';
import '../services/ad_manager.dart';

class ExpiringSubscriptionsScreen extends ConsumerStatefulWidget {
  const ExpiringSubscriptionsScreen({super.key});

  @override
  ConsumerState<ExpiringSubscriptionsScreen> createState() =>
      _ExpiringSubscriptionsScreenState();
}

class _ExpiringSubscriptionsScreenState
    extends ConsumerState<ExpiringSubscriptionsScreen> {
  final AdManager _adManager = AdManager();
  int _actionCount = 0; // Track user actions for intelligent ad serving
  String _filter = 'All Expiring'; // Default filter
  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    // Initialize banner ad
    await _adManager.initializeBannerAd(
      size: AdSize.banner,
      // Replace with your actual ad unit ID in production
      // adUnitId: 'your_banner_ad_unit_id_here',
    );

    // Initialize interstitial ad
    await _adManager.initializeInterstitialAd(
        // Replace with your actual ad unit ID in production
        //   adUnitId: 'your_interstitial_ad_unit_id_here',
        );
  }

  @override
  void dispose() {
    _adManager.dispose();
    super.dispose();
  }

  // Show interstitial after significant actions
  Future<void> _incrementActionAndShowAd() async {
    _actionCount++;
    if (_actionCount % 3 == 0) {
      // Show ad every 3 significant actions
      await _adManager.showInterstitialAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Subscriptions'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _filter,
              items:
                  ['Today', 'Next 3 Days', 'All Expiring'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _filter = newValue;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: expiringSubscriptions.when(
              data: (customers) {
                // Sort by expiration date (soonest first)
                customers.sort(
                    (a, b) => a.subscriptionEnd.compareTo(b.subscriptionEnd));
                final filteredCustomers = _applyFilter(customers);
                return filteredCustomers.isEmpty
                    ? const Center(
                        child: Text('No subscriptions expiring soon'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return _buildCustomerCard(customer, context);
                        },
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          // Banner ad at the bottom
          SafeArea(
            child: Center(
              child: _adManager.getBannerAdWidget(
                maxWidth: MediaQuery.of(context).size.width,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Customer> _applyFilter(List<Customer> customers) {
    final now = DateTime.now();
    switch (_filter) {
      case 'Today':
        return customers
            .where((c) => c.subscriptionEnd.day == now.day)
            .toList();
      case 'Next 3 Days':
        return customers
            .where((c) => c.subscriptionEnd.difference(now).inDays <= 3)
            .toList();
      case 'All Expiring':
      default:
        return customers;
    }
  }

  Widget _buildCustomerCard(Customer customer, BuildContext context) {
    final now = DateTime.now();
    final daysLeft = customer.subscriptionEnd.difference(now).inDays;
    final hoursLeft = customer.subscriptionEnd.difference(now).inHours % 24;
    final isExpired = customer.subscriptionEnd.isBefore(now);
    final expiresToday = daysLeft == 0 && !isExpired;

    Color urgencyColor;
    if (isExpired) {
      urgencyColor = Colors.redAccent;
    } else if (expiresToday) {
      urgencyColor = Colors.orangeAccent;
    } else {
      urgencyColor = Colors.yellowAccent;
    }

    String expiryText;
    if (isExpired) {
      expiryText = 'Expired ${-daysLeft} day${-daysLeft != 1 ? 's' : ''} ago';
    } else if (daysLeft > 0) {
      expiryText = 'Expires in $daysLeft day${daysLeft != 1 ? 's' : ''}';
    } else {
      expiryText = 'Expires in $hoursLeft hour${hoursLeft != 1 ? 's' : ''}';
    }
    final daysUntilExpiry =
        customer.subscriptionEnd.difference(DateTime.now()).inDays;
    return Semantics(
      label:
          'Customer ${customer.name}, subscription expires ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}, $expiryText, tap to renew',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        child: ListTile(
          title: Text(customer.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan: ${customer.planType.name}'),
              Text(
                expiryText,
                style:
                    TextStyle(color: urgencyColor, fontWeight: FontWeight.bold),
              ),
              Text(
                  '${_formatExpiryTime(customer.subscriptionEnd, daysUntilExpiry)}\n${DateFormat('MMM dd, yyyy - hh:mm a').format(customer.subscriptionEnd)}\nPlan: ${customer.planType.name}',
                  style: TextStyle(
                      color: urgencyColor, fontWeight: FontWeight.bold)),
              Semantics(
                label: 'Renew subscription for ${customer.name}',
                child: ElevatedButton(
                  onPressed: () {
                    _showRenewalDialog(context, ref, customer);
                    _incrementActionAndShowAd();
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Renew'),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () {
                  _makeCall(customer.contact);
                  _incrementActionAndShowAd();
                },
              ),
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  _sendMessage(
                    customer.contact,
                    context,
                    customer,
                    daysUntilExpiry,
                  );
                  _incrementActionAndShowAd();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatExpiryTime(DateTime subscriptionEnd, int daysUntilExpiry) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);

    if (daysUntilExpiry > 0) {
      return 'Expires: ${DateFormat('MMM d, y - hh:mm a').format(subscriptionEnd)}';
    } else if (difference.inHours.abs() < 24) {
      final hours = difference.inHours.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $hours hour${hours != 1 ? 's' : ''}';
    } else if (difference.inMinutes.abs() < 60) {
      final minutes = difference.inMinutes.abs();
      final prefix = difference.isNegative ? 'Expired' : 'Expires';
      return '$prefix in $minutes minute${minutes != 1 ? 's' : ''}';
    } else {
      final expiredDays = (-daysUntilExpiry).abs();
      return 'Expired $expiredDays day${expiredDays != 1 ? 's' : ''} ago';
    }
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
    Customer customer,
    int daysUntilExpiry,
  ) async {
    final messageOptions = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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

    final expiryStatus = _formatExpiryTime(
      customer.subscriptionEnd,
      daysUntilExpiry,
    );
    final planType = customer.planType.name;

    final message = Uri.encodeComponent(
      'Dear ${customer.name},\n\n'
      'This is a reminder regarding your WiFi subscription status:\n\n'
      '• Plan Type: $planType\n'
      '• Status: $expiryStatus\n\n'
      'Please renew your subscription to ensure uninterrupted service. '
      'You can process the renewal through our app or contact our support team.\n\n'
      'Thank you for choosing our services.\n\n'
      'Best regards,\n'
      'Your WiFi Service Provider',
    );

    final url = messageOptions == 'whatsapp'
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
      builder: (context) => AlertDialog(
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
