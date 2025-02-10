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
      appBar: AppBar(title: const Text('Expiring Subscriptions')),
      body: Column(
        children: [
          Expanded(
            child: expiringSubscriptions.when(
              data:
                  (customers) =>
                      customers.isEmpty
                          ? const Center(
                            child: Text('No expiring subscriptions'),
                          )
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
                                  backgroundColor: _getExpiryColor(
                                    daysUntilExpiry,
                                  ),
                                  child: Text(
                                    daysUntilExpiry.toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: Text(
                                  '${_formatExpiryTime(customer.subscriptionEnd, daysUntilExpiry)}\n${DateFormat('MMM dd, yyyy - hh:mm a').format(customer.subscriptionEnd)}\nPlan: ${customer.planType.name}',
                                ),
                                isThreeLine: true,
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
                                onTap: () {
                                  _showRenewalDialog(context, ref, customer);
                                  _incrementActionAndShowAd();
                                },
                              );
                            },
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
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

  Color _getExpiryColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 2) return Colors.orange;
    return Colors.yellow.shade700;
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
