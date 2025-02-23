import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../database/models/customer.dart';
import '../services/ad_manager.dart';
import '../utils.dart';
import '../widgets/add_payment_dialog.dart';
import 'edit_customer_screen.dart';
import 'referral_stats_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  final AdManager _adManager = AdManager();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    // Initialize two banner ads for different positions
    await _adManager.initializeBannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-8267064683737776/9972219205',
    );

    // Initialize interstitial ad
    await _adManager.initializeInterstitialAd(
      adUnitId: 'your_interstitial_ad_unit_id_here',
    );

    // Show initial interstitial if customer subscription is expired
    if (!_isDisposed &&
        widget.customer.subscriptionEnd.isBefore(DateTime.now())) {
      await _adManager.showInterstitialAd();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _adManager.dispose();
    super.dispose();
  }

  Future<void> _showInterstitialOnAction() async {
    await _adManager.showInterstitialAd();
  }

  void _shareCustomerLink() {
    final link = generateShareableLink(
        widget.customer.id.toString(), widget.customer.subscriptionEnd);
    print(link);
    Share.share('View my WiFi subscription details: $link');
  }

  @override
  Widget build(BuildContext context) {
    final daysUntilExpiry =
        widget.customer.subscriptionEnd.difference(DateTime.now()).inDays;
    final isExpiring = daysUntilExpiry <= 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () async {
              await _showInterstitialOnAction();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReferralStatsScreen(
                    referrerId: widget.customer.id.toString(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await _showInterstitialOnAction();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditCustomerScreen(customer: widget.customer),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                              'Subscription expires in ${_formatExpiryTime(widget.customer.subscriptionEnd, daysUntilExpiry)}',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showAddPaymentDialog(),
                            child: const Text('RENEW'),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Customer Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Contact', widget.customer.contact),
                        const Divider(),
                        _buildDetailRow('WiFi Name', widget.customer.wifiName),
                        const Divider(),
                        _buildDetailRow(
                          'Password',
                          widget.customer.currentPassword,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Status',
                          widget.customer.isActive ? 'Active' : 'Inactive',
                        ),
                        const Divider(),
                        _buildDetailRow('Plan', widget.customer.planType.name),
                        const Divider(),
                        _buildDetailRow(
                          'Subscription Start',
                          DateFormat(
                            'MMM d, y - hh:mm a',
                          ).format(widget.customer.subscriptionStart),
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Subscription End',
                          _formatExpiryTime(
                            widget.customer.subscriptionEnd,
                            daysUntilExpiry,
                          ),
                        ),
                        _buildDetailRow(
                          '',
                          DateFormat(
                            'MMM d, y - hh:mm a',
                          ).format(widget.customer.subscriptionEnd),
                        ),
                      ],
                    ),
                  ),
                ),
                // Ad placement between cards
                Center(
                  child: _adManager.getBannerAdWidget(
                    maxWidth: MediaQuery.of(context).size.width,
                  ),
                ),
                // Referral Program Card
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
                        _buildDetailRow(
                          'Your Referral Code',
                          widget.customer.referralCode,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share your referral code with friends to earn free subscription days!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            _shareReferralCode(
                              context,
                              widget.customer.referralCode,
                            );
                            await _showInterstitialOnAction();
                          },
                          child: const Text('Share Referral Code'),
                        ),
                        ElevatedButton(
                          onPressed: () => _shareCustomerLink(),
                          child: const Text('Share view link'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(),
        icon: const Icon(Icons.payment),
        label: const Text('Add Payment'),
      ),
    );
  }

  Future<void> _showAddPaymentDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const AddPaymentDialog(),
    );
    await _showInterstitialOnAction();
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
          SelectableText(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  String _formatExpiryTime(DateTime subscriptionEnd, int daysUntilExpiry) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);

    if (daysUntilExpiry > 0) {
      return DateFormat('MMM d, y').format(subscriptionEnd);
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

  void _shareReferralCode(BuildContext context, String referralCode) {
    final message = 'Join Truthy WiFi using my referral code: $referralCode';
    Share.share(message);
  }
}
