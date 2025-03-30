import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../database/models/customer.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';
import '../providers/customer_provider.dart';
import '../providers/payment_provider.dart';
import '../services/ad_manager.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/receipt_button.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  final Customer? initialCustomer;

  const PaymentsScreen({super.key, this.initialCustomer});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with TickerProviderStateMixin {
  final AdManager _adManager = AdManager();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _sortCriteria = 'date';
  bool _sortAscending = false;
  DateTimeRange? _quickFilterRange;
  late TabController _tabController;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAds();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    if (widget.initialCustomer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddPaymentDialog(context, initialCustomer: widget.initialCustomer);
      });
    }
  }

  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd(size: AdSize.mediumRectangle);
    await _adManager.initializeInterstitialAd();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _adManager.dispose();
    super.dispose();
  }

  void _applyQuickFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'Today':
          _quickFilterRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          );
          break;
        case 'This Week':
          // Find the first day of the week (Monday)
          final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
          _quickFilterRange = DateTimeRange(
            start: DateTime(
                firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day),
            end: now,
          );
          break;
        case 'This Month':
          _quickFilterRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
          break;
        case 'Last Month':
          final lastMonth = DateTime(now.year, now.month - 1);
          _quickFilterRange = DateTimeRange(
            start: DateTime(lastMonth.year, lastMonth.month, 1),
            end: DateTime(now.year, now.month, 0),
          );
          break;
        case 'This Quarter':
          final quarter = (now.month - 1) ~/ 3;
          _quickFilterRange = DateTimeRange(
            start: DateTime(now.year, quarter * 3 + 1, 1),
            end: now,
          );
          break;
        case 'All Time':
          _quickFilterRange = null;
          break;
        default:
          _quickFilterRange = null;
      }
    });

    ref.read(selectedDateRangeProvider.notifier).state = _quickFilterRange;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final initialDateRange = ref.read(selectedDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      saveText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _quickFilterRange = picked);
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }

  Icon _getPlanIcon(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return const Icon(Icons.calendar_today, color: Colors.blue);
      case PlanType.weekly:
        return const Icon(Icons.calendar_view_week, color: Colors.green);
      case PlanType.monthly:
        return const Icon(Icons.calendar_view_month, color: Colors.orange);
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_UG',
      symbol: 'UGX ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  List<Payment> _sortPayments(List<Payment> payments) {
    switch (_sortCriteria) {
      case 'date':
        payments.sort((a, b) => _sortAscending
            ? a.paymentDate.compareTo(b.paymentDate)
            : b.paymentDate.compareTo(a.paymentDate));
        break;
      case 'amount':
        payments.sort((a, b) => _sortAscending
            ? a.amount.compareTo(b.amount)
            : b.amount.compareTo(a.amount));
        break;
      case 'plan':
        payments.sort((a, b) => _sortAscending
            ? a.planType.name.compareTo(b.planType.name)
            : b.planType.name.compareTo(a.planType.name));
        break;
    }
    return payments;
  }

  List<Payment> _filterPaymentsByTab(List<Payment> payments, int tabIndex) {
    switch (tabIndex) {
      case 1: // Confirmed
        return payments.where((payment) => payment.isConfirmed).toList();
      case 2: // Pending
        return payments.where((payment) => !payment.isConfirmed).toList();
      case 0: // All
      default:
        return payments;
    }
  }

  List<Payment> _filterPaymentsBySearch(List<Payment> payments) {
    if (_searchQuery.isEmpty) return payments;

    return payments.where((payment) {
      // Get customer async, but we're in a sync function, so we need a workaround
      // We'll filter by customer ID for now, and the actual display will show customer name
      return payment.customerId.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPaymentsAsync = ref.watch(filteredPaymentsProvider);
    final paymentSummaryAsync = ref.watch(paymentSummaryProvider);
    final selectedDateRange = ref.watch(selectedDateRangeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: _isSearchExpanded
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search payments...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text('Payments'),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.search),
            tooltip: _isSearchExpanded ? 'Clear search' : 'Search payments',
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select date range',
            onPressed: () => _selectDateRange(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort payments',
            icon: Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortCriteria == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortCriteria = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      _sortCriteria == 'date'
                          ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : Icons.calendar_today,
                      size: 18,
                      color: _sortCriteria == 'date'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    SizedBox(width: 8),
                    Text('Sort by Date'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    Icon(
                      _sortCriteria == 'amount'
                          ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : Icons.attach_money,
                      size: 18,
                      color: _sortCriteria == 'amount'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    SizedBox(width: 8),
                    Text('Sort by Amount'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'plan',
                child: Row(
                  children: [
                    Icon(
                      _sortCriteria == 'plan'
                          ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : Icons.view_module,
                      size: 18,
                      color: _sortCriteria == 'plan'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    SizedBox(width: 8),
                    Text('Sort by Plan'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Pending'),
          ],
          indicatorColor: theme.colorScheme.primary,
          onTap: (_) {
            // Force rebuild when tab changes
            setState(() {});
          },
        ),
      ),
      body: Column(
        children: [
          // Quick filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final filter in [
                  'Today',
                  'This Week',
                  'This Month',
                  'Last Month',
                  'This Quarter',
                  'All Time'
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Semantics(
                      button: true,
                      label: 'Filter payments for $filter',
                      child: FilterChip(
                        label: Text(filter),
                        selected: _getFilterMatchesDateRange(
                            filter, _quickFilterRange),
                        onSelected: (_) => _applyQuickFilter(filter),
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor:
                            theme.colorScheme.primary.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getFilterMatchesDateRange(
                                    filter, _quickFilterRange)
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (selectedDateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text(
                        '${DateFormat('MMM d').format(selectedDateRange.start)} - ${DateFormat('MMM d').format(selectedDateRange.end)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      deleteIcon: Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _quickFilterRange = null);
                        ref.read(selectedDateRangeProvider.notifier).state =
                            null;
                      },
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Summary card at the top
          paymentSummaryAsync.when(
            data: (summary) => _buildSummaryCard(summary, theme),
            loading: () => SizedBox(height: 12),
            error: (_, __) => SizedBox(height: 12),
          ),

          // Main payment list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await ref.refresh(filteredPaymentsProvider.future);
                await ref.refresh(paymentSummaryProvider.future);
              },
              child: filteredPaymentsAsync.when(
                data: (payments) {
                  final filteredByTab =
                      _filterPaymentsByTab(payments, _tabController.index);
                  final filteredBySearch =
                      _filterPaymentsBySearch(filteredByTab);
                  final sortedPayments = _sortPayments(filteredBySearch);

                  if (sortedPayments.isEmpty) {
                    return _buildEmptyState(theme);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: sortedPayments.length,
                    itemBuilder: (context, index) {
                      final payment = sortedPayments[index];
                      return _buildPaymentCard(payment, context, theme);
                    },
                  );
                },
                loading: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading payments...'),
                    ],
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error loading payments'),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(filteredPaymentsProvider),
                        icon: Icon(Icons.refresh),
                        label: Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ad at the bottom
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _adManager.getBannerAdWidget(
              maxWidth: MediaQuery.of(context).size.width - 16,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_payment',
        isExtended: true,
        onPressed: () => _showAddPaymentDialog(context),
        tooltip: 'Add new payment',
        label: const Text('Add Payment'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  bool _getFilterMatchesDateRange(String filter, DateTimeRange? currentRange) {
    if (currentRange == null) return filter == 'All Time';

    final now = DateTime.now();
    switch (filter) {
      case 'Today':
        return currentRange.start.year == now.year &&
            currentRange.start.month == now.month &&
            currentRange.start.day == now.day &&
            currentRange.end.year == now.year &&
            currentRange.end.month == now.month &&
            currentRange.end.day == now.day;
      case 'This Week':
        final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return currentRange.start.year == firstDayOfWeek.year &&
            currentRange.start.month == firstDayOfWeek.month &&
            currentRange.start.day == firstDayOfWeek.day;
      case 'This Month':
        return currentRange.start.year == now.year &&
            currentRange.start.month == now.month &&
            currentRange.start.day == 1;
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1);
        return currentRange.start.year == lastMonth.year &&
            currentRange.start.month == lastMonth.month &&
            currentRange.start.day == 1;
      case 'This Quarter':
        final quarter = (now.month - 1) ~/ 3;
        return currentRange.start.year == now.year &&
            currentRange.start.month == quarter * 3 + 1 &&
            currentRange.start.day == 1;
      case 'All Time':
        return false;
      default:
        return false;
    }
  }

  Widget _buildSummaryCard(Map<String, double> summary, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Payment Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  _buildSummaryItem(
                    title: 'Total',
                    amount: summary['total'] ?? 0.0,
                    icon: Icons.account_balance_wallet,
                    color: theme.colorScheme.primary,
                    expanded: true,
                  ),
                  Container(height: 40, width: 1, color: theme.dividerColor),
                  _buildSummaryItem(
                    title: 'Daily',
                    amount: summary['daily'] ?? 0.0,
                    icon: Icons.calendar_today,
                    color: Colors.blue,
                  ),
                  Container(height: 40, width: 1, color: theme.dividerColor),
                  _buildSummaryItem(
                    title: 'Weekly',
                    amount: summary['weekly'] ?? 0.0,
                    icon: Icons.calendar_view_week,
                    color: Colors.green,
                  ),
                  Container(height: 40, width: 1, color: theme.dividerColor),
                  _buildSummaryItem(
                    title: 'Monthly',
                    amount: summary['monthly'] ?? 0.0,
                    icon: Icons.calendar_view_month,
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    bool expanded = false,
  }) {
    return Expanded(
      flex: expanded ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          label: '$title revenue: ${_formatAmount(amount)}',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatAmount(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: expanded ? 18 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(
      Payment payment, BuildContext context, ThemeData theme) {
    final customerAsync = ref.watch(customerProvider(payment.customerId));

    return Semantics(
      label:
          'Payment of ${_formatAmount(payment.amount)} for ${payment.planType.name} plan on ${DateFormat('MMM d, y').format(payment.paymentDate)}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showPaymentDetails(context, payment),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPlanColor(payment.planType).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: _getPlanIcon(payment.planType),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatAmount(payment.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _buildStatusChip(payment.isConfirmed, theme),
                            ],
                          ),
                          SizedBox(height: 4),
                          customerAsync.when(
                            data: (customer) => Text(
                              customer?.name ?? 'Unknown Customer',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                            loading: () => Text(
                              'Loading customer...',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            error: (_, __) => Text(
                              'Unknown Customer',
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Divider(height: 1),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(payment.paymentDate),
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          payment.planType.name.toUpperCase(),
                          style: TextStyle(
                            color: _getPlanColor(payment.planType),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        ReceiptButton(payment: payment),
                      ],
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

  Widget _buildStatusChip(bool isConfirmed, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed
            ? Colors.green.withOpacity(0.2)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.pending,
            size: 12,
            color: isConfirmed ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 4),
          Text(
            isConfirmed ? 'Confirmed' : 'Pending',
            style: TextStyle(
              color: isConfirmed ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(PlanType planType) {
    switch (planType) {
      case PlanType.daily:
        return Colors.blue;
      case PlanType.weekly:
        return Colors.green;
      case PlanType.monthly:
        return Colors.orange;
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    String message;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      message = 'No payments found for "$_searchQuery"';
      icon = Icons.search_off;
    } else if (ref.read(selectedDateRangeProvider) != null) {
      message = 'No payments found in the selected date range';
      icon = Icons.date_range;
    } else {
      switch (_tabController.index) {
        case 1:
          message = 'No confirmed payments found';
          icon = Icons.check_circle_outline;
          break;
        case 2:
          message = 'No pending payments found';
          icon = Icons.pending_outlined;
          break;
        default:
          message = 'No payments found';
          icon = Icons.payments_outlined;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (_searchQuery.isNotEmpty ||
              ref.read(selectedDateRangeProvider) != null)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearchExpanded = false;
                });
                ref.read(selectedDateRangeProvider.notifier).state = null;
                setState(() => _quickFilterRange = null);
              },
              icon: Icon(Icons.clear),
              label: Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDetails(
      BuildContext context, Payment payment) async {
    final customerAsync = ref.watch(customerProvider(payment.customerId));

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          padding: EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: EdgeInsets.only(bottom: 16),
                ),
              ),
              Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),

              // Amount with plan icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getPlanColor(payment.planType).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: _getPlanIcon(payment.planType)),
                  ),
                  SizedBox(width: 12),
                  Text(
                    _formatAmount(payment.amount),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),
              _buildDetailItem('Payment Date',
                  DateFormat('MMMM d, y - h:mm a').format(payment.paymentDate)),
              SizedBox(height: 8),
              _buildDetailItem('Payment ID', payment.id),
              SizedBox(height: 8),
              _buildDetailItem(
                  'Plan Type', payment.planType.name.toUpperCase()),
              SizedBox(height: 8),
              _buildDetailItem(
                  'Status', payment.isConfirmed ? 'Confirmed' : 'Pending'),
              SizedBox(height: 8),

              // Customer info
              customerAsync.when(
                data: (customer) => customer != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 32),
                          Text(
                            'Customer Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _buildDetailItem('Name', customer.name),
                          SizedBox(height: 8),
                          _buildDetailItem('Contact', customer.contact),
                          SizedBox(height: 8),
                          _buildDetailItem('Subscription',
                              '${DateFormat('MMM d, y').format(customer.subscriptionStart)} - ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}'),
                        ],
                      )
                    : SizedBox(),
                loading: () => Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => SizedBox(),
              ),

              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('EDIT'),
                    onPressed: () {
                      Navigator.pop(context);
                      // Implement edit payment
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.receipt),
                    label: Text('RECEIPT'),
                    onPressed: () {
                      Navigator.pop(context);
                      // Generate receipt
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddPaymentDialog(BuildContext context,
      {Customer? initialCustomer}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddPaymentDialog(customer: initialCustomer),
    );

    if (result == true) {
      await ref.refresh(filteredPaymentsProvider.future);
      await ref.refresh(paymentSummaryProvider.future);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment added successfully'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              _tabController.animateTo(0); // Switch to All tab
            },
          ),
        ),
      );
    }
  }
}
