import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../services/ad_manager.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final AdManager _adManager = AdManager();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  static const int _itemsPerAd = 8; // Show ad every 8 items

  @override
  void initState() {
    super.initState();
    _initializeAds();
    _setupScrollListener();
  }

  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd();
    await _adManager.initializeInterstitialAd();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent * 0.7) {
        _loadMoreAds();
      }
    });
  }

  Future<void> _loadMoreAds() async {
    if (!_isLoadingMore) {
      setState(() => _isLoadingMore = true);
      await _adManager.initializeInterstitialAd();
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleCustomerTap(
    BuildContext context,
    Customer customer,
  ) async {
    // Show interstitial ad with 20% probability when viewing customer details
    if (!_isLoadingMore && DateTime.now().second % 5 == 0) {
      final bool adShown = await _adManager.showInterstitialAd();
      if (adShown) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (mounted) {
      Navigator.pushNamed(
        context,
        '/customer/${customer.id}',
        arguments: customer,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _adManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(activeCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/inactive-customers');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: customersAsync.when(
              data:
                  (customers) =>
                      customers.isEmpty
                          ? const Center(child: Text('No active customers'))
                          : ListView.builder(
                            controller: _scrollController,
                            itemCount:
                                customers.length +
                                (customers.length ~/ _itemsPerAd),
                            itemBuilder: (context, index) {
                              // Calculate actual customer index accounting for ad positions
                              final customerIndex =
                                  index - (index ~/ (_itemsPerAd + 1));

                              // Show ad banner every _itemsPerAd items
                              if (index > 0 && index % (_itemsPerAd + 1) == 0) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: _adManager.getBannerAdWidget(
                                      maxWidth:
                                          MediaQuery.of(context).size.width -
                                          32,
                                    ),
                                  ),
                                );
                              }

                              final customer = customers[customerIndex];
                              return CustomerListTile(
                                customer: customer,
                                onTap:
                                    () => _handleCustomerTap(context, customer),
                              );
                            },
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
          // Persistent banner ad at the bottom
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: _adManager.getBannerAdWidget(
                maxWidth: MediaQuery.of(context).size.width,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerListTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerListTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Expires: ${DateFormat('MMM dd, yyyy - hh:mm a').format(customer.subscriptionEnd)}',
              style: TextStyle(
                color:
                    customer.subscriptionEnd.difference(DateTime.now()).inDays <
                            3
                        ? Colors.red
                        : null,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed:
              () => Navigator.pushNamed(
                context,
                '/edit-customer/${customer.id}',
                arguments: customer,
              ),
        ),
      ),
    );
  }
}
