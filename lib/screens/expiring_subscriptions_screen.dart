import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/models/customer.dart';
import '../database/models/plan.dart';
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
  int _actionCount = 0;
  String _filter = 'All Expiring';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;
  String? _sortBy = 'date'; // 'date', 'name', 'plan'
  bool _sortAscending = false;
  bool _actionsVisible = false;
  Set<String> _selectedCustomerIds = {};

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
    await _adManager.initializeBannerAd(
      size: AdSize.banner,
    );
    await _adManager.initializeInterstitialAd();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adManager.dispose();
    super.dispose();
  }

  Future<void> _incrementActionAndShowAd() async {
    _actionCount++;
    if (_actionCount % 3 == 0) {
      await _adManager.showInterstitialAd();
    }
  }

  List<Customer> _applyFilter(List<Customer> customers) {
    final now = DateTime.now();

    // First apply search filter
    var filteredCustomers = customers;
    if (_searchQuery.isNotEmpty) {
      filteredCustomers = customers.where((customer) {
        return customer.name.toLowerCase().contains(_searchQuery) ||
            customer.contact.toLowerCase().contains(_searchQuery) ||
            customer.planType.name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Then apply date filter
    switch (_filter) {
      case 'Today':
        filteredCustomers = filteredCustomers
            .where((c) =>
                c.subscriptionEnd.day == now.day &&
                c.subscriptionEnd.month == now.month &&
                c.subscriptionEnd.year == now.year)
            .toList();
        break;
      case 'Next 3 Days':
        final threeDaysLater = now.add(const Duration(days: 3));
        filteredCustomers = filteredCustomers
            .where((c) =>
                c.subscriptionEnd.isAfter(now) &&
                c.subscriptionEnd.isBefore(threeDaysLater))
            .toList();
        break;
      case 'Expired':
        filteredCustomers = filteredCustomers
            .where((c) => c.subscriptionEnd.isBefore(now))
            .toList();
        break;
      case 'All Expiring':
      default:
        // Keep all
        break;
    }

    // Then apply sorting
    if (_sortBy != null) {
      filteredCustomers.sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'date':
            comparison = a.subscriptionEnd.compareTo(b.subscriptionEnd);
            break;
          case 'name':
            comparison = a.name.compareTo(b.name);
            break;
          case 'plan':
            comparison = a.planType.name.compareTo(b.planType.name);
            break;
          default:
            comparison = a.subscriptionEnd.compareTo(b.subscriptionEnd);
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    return filteredCustomers;
  }

  void _toggleSelectCustomer(String customerId) {
    setState(() {
      if (_selectedCustomerIds.contains(customerId)) {
        _selectedCustomerIds.remove(customerId);
      } else {
        _selectedCustomerIds.add(customerId);
      }

      // Hide actions bar if no customers selected
      if (_selectedCustomerIds.isEmpty) {
        _actionsVisible = false;
      }
    });
  }

  void _selectAll(List<Customer> customers) {
    setState(() {
      if (_selectedCustomerIds.length == customers.length) {
        // If all are selected, deselect all
        _selectedCustomerIds.clear();
        _actionsVisible = false;
      } else {
        // Select all
        _selectedCustomerIds = customers.map((c) => c.id).toSet();
        _actionsVisible = true;
      }
    });
  }

  Future<void> _sendBulkMessage(List<Customer> selectedCustomers) async {
    if (selectedCustomers.isEmpty) return;

    final messageType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Bulk Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send message to ${selectedCustomers.length} customers'),
            const SizedBox(height: 16),
            const Text('Choose message type:'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'sms'),
            child: const Text('SMS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'whatsapp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );

    if (messageType == null || messageType == 'cancel') return;

    // Let's take the first customer as an example (normally we'd do this for each)
    if (selectedCustomers.isNotEmpty) {
      final customer = selectedCustomers.first;
      _sendMessage(customer.contact, context, customer,
          customer.subscriptionEnd.difference(DateTime.now()).inDays);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${messageType == 'sms' ? 'SMS' : 'WhatsApp'} message started for ${selectedCustomers.length} customers'),
          action: SnackBarAction(
            label: 'DISMISS',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _renewBulk(List<Customer> selectedCustomers) async {
    if (selectedCustomers.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew Subscriptions'),
        content: Text(
            'Do you want to renew ${selectedCustomers.length} subscriptions?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RENEW'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Navigate to payments screen with the first customer
      // In a real implementation, you might want to handle batch renewals
      if (selectedCustomers.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/payments',
          arguments: selectedCustomers.first,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearchVisible
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearchVisible = false;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Expiring Subscriptions'),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.cancel : Icons.search),
            tooltip: _isSearchVisible ? 'Cancel search' : 'Search customers',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter options',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem('Today', Icons.today),
              _buildPopupMenuItem('Next 3 Days', Icons.date_range),
              _buildPopupMenuItem('Expired', Icons.history),
              _buildPopupMenuItem('All Expiring', Icons.list),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort options',
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              _buildSortMenuItem(
                  'date', 'Expiration Date', Icons.calendar_today),
              _buildSortMenuItem('name', 'Customer Name', Icons.person),
              _buildSortMenuItem('plan', 'Plan Type', Icons.category),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter indicator chip
          if (!_isSearchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Chip(
                    label: Text('Filter: $_filter'),
                    deleteIcon: _filter != 'All Expiring'
                        ? const Icon(Icons.clear, size: 18)
                        : null,
                    onDeleted: _filter != 'All Expiring'
                        ? () => setState(() => _filter = 'All Expiring')
                        : null,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  if (_sortBy != null)
                    Chip(
                      label: Text(
                          'Sort: ${_getSortLabel(_sortBy!)} ${_sortAscending ? '↑' : '↓'}'),
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty)
                    Chip(
                      label: Text('Search: $_searchQuery'),
                      deleteIcon: const Icon(Icons.clear, size: 18),
                      onDeleted: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                ],
              ),
            ),

          // Bulk action bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _actionsVisible ? 60 : 0,
            color: theme.colorScheme.primaryContainer,
            child: _actionsVisible
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedCustomerIds.length} selected',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.message),
                          tooltip: 'Send messages',
                          onPressed: () =>
                              expiringSubscriptions.whenData((customers) {
                            final selectedCustomers = customers
                                .where(
                                    (c) => _selectedCustomerIds.contains(c.id))
                                .toList();
                            _sendBulkMessage(selectedCustomers);
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Renew selected',
                          onPressed: () =>
                              expiringSubscriptions.whenData((customers) {
                            final selectedCustomers = customers
                                .where(
                                    (c) => _selectedCustomerIds.contains(c.id))
                                .toList();
                            _renewBulk(selectedCustomers);
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear selection',
                          onPressed: () {
                            setState(() {
                              _selectedCustomerIds.clear();
                              _actionsVisible = false;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          Expanded(
            child: expiringSubscriptions.when(
              data: (customers) {
                final filteredCustomers = _applyFilter(customers);

                if (filteredCustomers.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(expiringSubscriptionsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount:
                        filteredCustomers.length + 1, // +1 for the header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // This is the header with the select all checkbox
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selectedCustomerIds.length ==
                                        filteredCustomers.length &&
                                    filteredCustomers.isNotEmpty,
                                onChanged: (_) => _selectAll(filteredCustomers),
                              ),
                              Text(
                                'Select All (${filteredCustomers.length})',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const Spacer(),
                              if (!_actionsVisible &&
                                  _selectedCustomerIds.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.check_box),
                                  label: const Text('Show Actions'),
                                  onPressed: () {
                                    setState(() {
                                      _actionsVisible = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }

                      final customer = filteredCustomers[index - 1];
                      return Semantics(
                        customSemanticsActions: {
                          CustomSemanticsAction(label: 'Call'): () =>
                              _makeCall(customer.contact),
                          CustomSemanticsAction(label: 'Message'): () =>
                              _sendMessage(
                                customer.contact,
                                context,
                                customer,
                                customer.subscriptionEnd
                                    .difference(DateTime.now())
                                    .inDays,
                              ),
                          CustomSemanticsAction(label: 'Renew'): () =>
                              _showRenewalDialog(context, ref, customer),
                        },
                        child: _buildEnhancedCustomerCard(
                            customer, theme, index - 1),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.refresh(expiringSubscriptionsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: _adManager.getBannerAdWidget(
                maxWidth: MediaQuery.of(context).size.width,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/add-customer');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
        tooltip: 'Add a new customer',
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: _filter == value
                  ? Theme.of(context).colorScheme.primary
                  : null),
          const SizedBox(width: 8),
          Text(value),
          if (_filter == value)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
      String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: _sortBy == value
                  ? Theme.of(context).colorScheme.primary
                  : null),
          const SizedBox(width: 8),
          Text(label),
          if (_sortBy == value)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'date':
        return 'Date';
      case 'name':
        return 'Name';
      case 'plan':
        return 'Plan';
      default:
        return 'Date';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    String message;
    IconData icon;
    Widget? action;

    if (_searchQuery.isNotEmpty) {
      message = 'No customers match your search "$_searchQuery"';
      icon = Icons.search_off;
      action = TextButton.icon(
        icon: const Icon(Icons.clear),
        label: const Text('Clear Search'),
        onPressed: () {
          _searchController.clear();
          setState(() {
            _isSearchVisible = false;
          });
        },
      );
    } else if (_filter != 'All Expiring') {
      message = 'No subscriptions found for "$_filter" filter';
      icon = Icons.filter_list_off;
      action = TextButton.icon(
        icon: const Icon(Icons.clear),
        label: const Text('Clear Filter'),
        onPressed: () {
          setState(() {
            _filter = 'All Expiring';
          });
        },
      );
    } else {
      message = 'No expiring subscriptions found';
      icon = Icons.check_circle_outline;
      action = TextButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        onPressed: () => ref.refresh(expiringSubscriptionsProvider),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style:
                theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildEnhancedCustomerCard(
      Customer customer, ThemeData theme, int index) {
    final now = DateTime.now();
    final daysLeft = customer.subscriptionEnd.difference(now).inDays;
    final hoursLeft = customer.subscriptionEnd.difference(now).inHours % 24;
    final isExpired = customer.subscriptionEnd.isBefore(now);
    final expiresToday = daysLeft == 0 && !isExpired;

    // Determine card color based on urgency
    Color cardColor;
    Color textColor;

    if (isExpired) {
      cardColor = Colors.red.shade900;
      textColor = Colors.white;
    } else if (expiresToday) {
      cardColor = Colors.orange.shade800;
      textColor = Colors.white;
    } else if (daysLeft <= 1) {
      cardColor = Colors.amber.shade700;
      textColor = Colors.black;
    } else {
      cardColor = theme.cardTheme.color ?? Colors.white.withOpacity(0.1);
      textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    }

    // Format expiry text
    String expiryText;
    if (isExpired) {
      expiryText = 'Expired ${-daysLeft} day${-daysLeft != 1 ? 's' : ''} ago';
    } else if (daysLeft > 0) {
      expiryText = 'Expires in $daysLeft day${daysLeft != 1 ? 's' : ''}';
    } else {
      expiryText = 'Expires in $hoursLeft hour${hoursLeft != 1 ? 's' : ''}';
    }

    // Format detailed time
    final formattedTime =
        DateFormat('MMM dd, yyyy - hh:mm a').format(customer.subscriptionEnd);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: index % 2 == 0
              ? BorderSide(color: theme.dividerColor.withOpacity(0.2), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/customer/${customer.id}',
              arguments: customer,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Checkbox(
                        value: _selectedCustomerIds.contains(customer.id),
                        onChanged: (_) {
                          _toggleSelectCustomer(customer.id);
                        },
                      ),
                    ),

                    // Customer avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.2),
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Customer details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.sim_card,
                                size: 14,
                                color: textColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                customer.contact,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textColor.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _getPlanIcon(customer.planType),
                                size: 14,
                                color: textColor.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${customer.planType.name.toUpperCase()} Plan',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textColor.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Expiration info with visual indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withOpacity(0.2)
                        : expiresToday
                            ? Colors.orange.withOpacity(0.2)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isExpired
                                ? Icons.schedule
                                : expiresToday
                                    ? Icons.warning_amber
                                    : Icons.access_time,
                            size: 16,
                            color: textColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            expiryText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),

                      // Progress indicator for remaining time
                      if (!isExpired)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _getTimeProgress(customer),
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              color: isExpired
                                  ? Colors.red
                                  : expiresToday
                                      ? Colors.orange
                                      : Colors.green,
                              minHeight: 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Call button
                    Semantics(
                      label: 'Call ${customer.name}',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          Icons.phone,
                          color: textColor.withOpacity(0.9),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surface.withOpacity(0.3),
                        ),
                        onPressed: () {
                          _makeCall(customer.contact);
                          _incrementActionAndShowAd();
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Message button
                    Semantics(
                      label: 'Message ${customer.name}',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          Icons.message,
                          color: textColor.withOpacity(0.9),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surface.withOpacity(0.3),
                        ),
                        onPressed: () {
                          _sendMessage(
                            customer.contact,
                            context,
                            customer,
                            daysLeft,
                          );
                          _incrementActionAndShowAd();
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Renew button
                    Semantics(
                      label: 'Renew subscription for ${customer.name}',
                      button: true,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.autorenew),
                        label: const Text('Renew'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          _showRenewalDialog(context, ref, customer);
                          _incrementActionAndShowAd();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getTimeProgress(Customer customer) {
    final now = DateTime.now();

    // If already expired, return 0
    if (customer.subscriptionEnd.isBefore(now)) {
      return 0;
    }

    // For simplicity, assume subscription length is 30 days for progress calculation
    final totalDuration = const Duration(days: 30);
    final timeLeft = customer.subscriptionEnd.difference(now);

    // Calculate progress as percentage of time remaining
    final progress = 1 - (timeLeft.inSeconds / totalDuration.inSeconds);

    // Ensure within bounds
    return progress.clamp(0.0, 1.0);
  }

  IconData _getPlanIcon(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return Icons.calendar_today;
      case PlanType.weekly:
        return Icons.calendar_view_week;
      case PlanType.monthly:
        return Icons.calendar_view_month;
    }
  }

  Future<void> _makeCall(String contact) async {
    final url = Uri.parse('tel:$contact');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot make call')),
        );
      }
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
              leading: Icon(Icons.chat, color: Colors.green),
              title: const Text('WhatsApp'),
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
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send message')),
        );
      }
    }
  }

  String _formatExpiryTime(DateTime subscriptionEnd, int daysUntilExpiry) {
    final now = DateTime.now();
    final difference = subscriptionEnd.difference(now);

    if (daysUntilExpiry > 0) {
      return 'Expires on ${DateFormat('MMM d, y').format(subscriptionEnd)} (in $daysUntilExpiry days)';
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

  Future<void> _showRenewalDialog(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Renew ${customer.name}\'s ${customer.planType.name} plan?'),
            const SizedBox(height: 16),
            Text(
              'Current subscription ends: ${DateFormat('MMM d, y - h:mm a').format(customer.subscriptionEnd)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('RENEW'),
          ),
        ],
      ),
    );
  }
}
