import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _adManager.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(activeCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_off_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/inactive-customers');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? Semantics(
                        label: 'Clear search query',
                        child: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                final filteredCustomers = customers
                    .where((customer) =>
                        customer.name.toLowerCase().contains(_searchQuery))
                    .toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Showing ${filteredCustomers.length} active customers',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.refresh(activeCustomersProvider
                            as Refreshable<Future<void>>),
                        child: ListView.builder(
                          //itemCount: filteredCustomers.length,
                            controller: _scrollController,
                          itemCount: filteredCustomers.length +
                              (filteredCustomers.length ~/ _itemsPerAd),
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
                                        MediaQuery.of(context).size.width - 32,
                                  ),
                                ),
                              );
                            }
                            //                         itemBuilder: (context, index) {
                            final customer = filteredCustomers[customerIndex];
                            return Semantics(
                              button: true,
                              label:
                                  'View details for customer ${customer.name}, subscription ends on ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}, plan: ${customer.planType.name}',
                              excludeSemantics: true,
                              child: ListTile(
                                title: Text(
                                  customer.name,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                subtitle: Text(
                                  customer.subscriptionEnd
                                          .isBefore(DateTime.now())
                                      ? 'Ended :${DateFormat('MMM d, y - hh:mm a').format(customer.subscriptionEnd)} • ${customer.planType.name}'
                                      : 'Ends: ${DateFormat('MMM d, y - hh:mm a').format(customer.subscriptionEnd)} • ${customer.planType.name}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Semantics(
                                      label: 'Call customer ${customer.name}',
                                      child: IconButton(
                                        icon: const Icon(Icons.phone, size: 24),
                                        padding: const EdgeInsets.all(12.0),
                                        onPressed: () =>
                                            _launchPhone(customer.contact),
                                      ),
                                    ),
                                    Semantics(
                                      label:
                                          'Message customer ${customer.name}',
                                      child: IconButton(
                                        icon:
                                            const Icon(Icons.message, size: 24),
                                        padding: const EdgeInsets.all(12.0),
                                        onPressed: () => _launchSMS(
                                            customer.contact, customer),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _handleCustomerTap(context, customer);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => Center(
                child: Semantics(
                  label: 'Loading customers',
                  child: const CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Failed to load customers. Please try again.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Retry loading customers',
                      child: ElevatedButton(
                        onPressed: () => ref.refresh(activeCustomersProvider),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
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

  Future<void> _launchPhone(String contact) async {
    final url = Uri.parse('tel:$contact');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchSMS(String contact, Customer customer) async {
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
    final message = Uri.encodeComponent('Hello ${customer.name},\n\n');
    final url = messageOptions == 'whatsapp'
        ? Uri.parse(
            'https://wa.me/${contact.replaceAll(RegExp(r'[^0-9]'), '')}?text=$message',
          )
        : Uri.parse('sms:$contact?body=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
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
          onPressed: () => Navigator.pushNamed(
            context,
            '/edit-customer/${customer.id}',
            arguments: customer,
          ),
        ),
      ),
    );
  }
}
//  controller: _scrollController,
//                       itemCount:
//                           customers.length + (customers.length ~/ _itemsPerAd),
//                       itemBuilder: (context, index) {
//                         // Calculate actual customer index accounting for ad positions
//                         final customerIndex =
//                             index - (index ~/ (_itemsPerAd + 1));

//                         // Show ad banner every _itemsPerAd items
//                         if (index > 0 && index % (_itemsPerAd + 1) == 0) {
//                           return Card(
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 vertical: 8,
//                               ),
//                               child: _adManager.getBannerAdWidget(
//                                 maxWidth:
//                                     MediaQuery.of(context).size.width - 32,
//                               ),
//                             ),
//                           );
//                         }
