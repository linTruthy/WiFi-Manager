import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/retention_provider.dart';
import '../services/ad_manager.dart';
import '../services/subscription_widget_service.dart';
import 'auth/login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AdManager _adManager = AdManager();
  String _filter = 'This Month';
  final GlobalKey _customersKey = GlobalKey();
  final GlobalKey _paymentsKey = GlobalKey();
  final GlobalKey _expiringKey = GlobalKey();
  final GlobalKey _retentionKey = GlobalKey();
  final _filterKey = GlobalKey();
  final _quickActionsKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  // Enhanced state management
  bool _isDarkMode = true;
  bool _isHighContrastMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
    _initializeAds();
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _adManager.initializeInterstitialAd();
    });

    // Start refreshing data immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      // Use Future.wait to refresh multiple providers concurrently
      await Future.wait([
        ref.refresh(expiringSubscriptionsProvider.future),
        ref.refresh(activeCustomersProvider.future),
        ref.refresh(paymentSummaryProvider.future),
        ref.refresh(scheduledNotificationsProvider.future),
        ref.refresh(retentionProvider.future),
      ]);

      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to refresh data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd();
    await _adManager.initializeInterstitialAd();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  void _toggleHighContrast() {
    setState(() {
      _isHighContrastMode = !_isHighContrastMode;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      } else {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    if (authService.currentUser == null) return const LoginScreen();

    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final activeCustomers = ref.watch(activeCustomersProvider);
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
    final retentionData = ref.watch(retentionProvider);
    final payments = ref.watch(paymentSummaryProvider);

    // Sync data with home screen widget
    ref.listen(expiringSubscriptionsProvider, (previous, next) {
      next.whenData((customers) {
        activeCustomers.whenData((activeCount) {
          ref.watch(paymentSummaryProvider).whenData((summary) {
            SubscriptionWidgetService.updateWidgetData(
              customers,
              activeCount.length,
              summary['total'] ?? 0.0,
            );
          });
        });
      });
    });

    return Scaffold(
      backgroundColor:
          _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(expiringSubscriptions),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          if (!_isHighContrastMode)
            _AnimatedBackground(isDarkMode: _isDarkMode),
          RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshData,
            color: theme.colorScheme.primary,
            backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
            child: SafeArea(
              child: _isLoading && activeCustomers is AsyncLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search bar (only if search mode is active)
                                if (_isSearching) _buildSearchBar(),
                                _buildFilterBar(),
                                const SizedBox(height: 16),
                                _buildSummarySection(
                                  activeCustomers,
                                  expiringSubscriptions,
                                  payments,
                                  retentionData,
                                ),
                                const SizedBox(height: 24),
                                // Revenue chart
                                _buildRevenueChart(payments),
                                const SizedBox(height: 16),
                                _buildAdWidget(),
                                const SizedBox(height: 24),
                                _buildQuickActionsSection(),
                                const SizedBox(height: 24),
                                _buildExpiringSubscriptionsSection(
                                    expiringSubscriptions),
                                const SizedBox(height: 16),
                                _buildAdWidget(maxWidth: mediaQuery.size.width),
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar(
      AsyncValue<List<Customer>> expiringSubscriptions) {
    return AppBar(
      title: _isSearching
          ? const SizedBox.shrink()
          : const Text(
              'WiFi Manager Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: (_isDarkMode ? Colors.black : Colors.white).withOpacity(0.2),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          tooltip: _isSearching ? 'Close search' : 'Search',
          onPressed: _toggleSearch,
        ),
        _buildNotificationButton(expiringSubscriptions),
        IconButton(
          icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
          tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
          onPressed: _toggleDarkMode,
        ),
        IconButton(
          icon: const Icon(Icons.accessibility_new),
          tooltip: 'Toggle high contrast',
          onPressed: _toggleHighContrast,
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Help',
          onPressed: () => Navigator.pushNamed(context, '/how-to'),
        ),
      ],
    );
  }

  Widget _buildNotificationButton(
      AsyncValue<List<Customer>> expiringSubscriptions) {
    // Get scheduled notifications count
    final scheduledNotificationsAsync =
        ref.watch(scheduledNotificationsProvider);

    return Stack(
      key: _notificationsKey,
      children: [
        IconButton(
          icon: const Icon(CupertinoIcons.bell),
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, '/scheduled-reminders'),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: scheduledNotificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  notifications.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              ref.read(authServiceProvider).currentUser?.displayName ??
                  'WiFi Manager',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              ref.read(authServiceProvider).currentUser?.email ?? '',
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue[700]),
            ),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              image: DecorationImage(
                image: AssetImage('assets/drawer_header_bg.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.blue.withOpacity(0.6),
                  BlendMode.srcOver,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard',
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.people,
            title: 'Customers',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/customers');
            },
          ),
          _buildDrawerItem(
            icon: Icons.payment,
            title: 'Payments',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/payments');
            },
          ),
          _buildDrawerItem(
            icon: Icons.timeline,
            title: 'Retention',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/retention');
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
          ),
          _buildDrawerItem(
            icon: Icons.help_outline,
            title: 'Help & Tutorials',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/how-to');
            },
          ),
          _buildDrawerItem(
            icon: Icons.info_outline,
            title: 'About',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/about');
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search customers, payments...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: _isDarkMode
              ? Colors.grey[800]!.withOpacity(0.5)
              : Colors.white.withOpacity(0.9),
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            Navigator.pushNamed(context, '/customers');
          }
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      key: _filterKey,
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['Today', 'This Week', 'This Month', 'This Year']
            .map((filter) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = filter);
                    },
                    selectedColor: _isHighContrastMode
                        ? Colors.yellow
                        : Colors.blueAccent.withOpacity(0.3),
                    backgroundColor: _isDarkMode
                        ? Colors.grey[800]!.withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                    labelStyle: TextStyle(
                      color: _isHighContrastMode
                          ? (_filter == filter ? Colors.black : Colors.white)
                          : (_filter == filter ? Colors.white : Colors.white70),
                      fontWeight: _filter == filter
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    elevation: 2,
                    pressElevation: 4,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSummarySection(
    AsyncValue<List<Customer>> activeCustomers,
    AsyncValue<List<Customer>> expiringSubscriptions,
    AsyncValue<Map<String, double>> payments,
    AsyncValue<Map<String, dynamic>> retentionData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isHighContrastMode ? Colors.yellow : null,
            ),
          ),
        ),
        SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildSummaryCard(
              key: _customersKey,
              title: "Active Customers",
              icon: Icons.people,
              color: Colors.green,
              value: activeCustomers.when(
                data: (customers) => customers.length.toString(),
                loading: () => "-",
                error: (_, __) => "Error",
              ),
              semanticLabel: "Active customers count",
              route: '/customers',
              trend: retentionData.when(
                data: (data) =>
                    data['activeCount'] != null && data['inactiveCount'] != null
                        ? ((data['activeCount'] /
                                        (data['activeCount'] +
                                            data['inactiveCount'])) *
                                    100)
                                .toStringAsFixed(1) +
                            '%'
                        : null,
                loading: () => null,
                error: (_, __) => null,
              ),
              isUp: true,
            ),
            _buildSummaryCard(
              key: _expiringKey,
              title: "Expiring Soon",
              icon: Icons.schedule,
              color: Colors.orange,
              value: expiringSubscriptions.when(
                data: (customers) => customers.length.toString(),
                loading: () => "-",
                error: (_, __) => "Error",
              ),
              semanticLabel: "Subscriptions expiring soon",
              route: '/expiring-subscriptions',
            ),
            _buildSummaryCard(
              key: _paymentsKey,
              title: "Revenue",
              icon: Icons.payments,
              color: Colors.blue,
              value: payments.when(
                data: (value) =>
                    "UGX " + (value['total']?.toStringAsFixed(0) ?? "0"),
                loading: () => "-",
                error: (_, __) => "Error",
              ),
              period: _filter,
              semanticLabel: "Total revenue",
              route: '/payments',
            ),
            _buildSummaryCard(
              key: _retentionKey,
              title: "Retention",
              icon: Icons.pie_chart,
              color: Colors.purple,
              value: retentionData.when(
                data: (data) => data['retentionRate'] != null
                    ? "${data['retentionRate'].toStringAsFixed(1)}%"
                    : "-",
                loading: () => "-",
                error: (_, __) => "Error",
              ),
              semanticLabel: "Customer retention rate",
              route: '/retention',
              trend: retentionData.when(
                data: (data) => data['newCustomersLast30Days'] != null
                    ? "+${data['newCustomersLast30Days']} new"
                    : null,
                loading: () => null,
                error: (_, __) => null,
              ),
              isUp: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required Key key,
    required String title,
    required IconData icon,
    required Color color,
    required String value,
    String? period,
    String? trend,
    bool isUp = true,
    required String semanticLabel,
    required String route,
  }) {
    final cardColor = _isHighContrastMode
        ? (_isDarkMode ? Colors.black : Colors.white)
        : (_isDarkMode ? Colors.grey[850] : Colors.white);

    final textColor = _isHighContrastMode
        ? (_isDarkMode ? Colors.yellow : Colors.black)
        : color;

    return Semantics(
      button: true,
      label: semanticLabel,
      value: value,
      onTapHint: "View details",
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: key,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: _isHighContrastMode
                  ? (_isDarkMode ? Colors.yellow : Colors.black)
                  : color.withOpacity(0.3),
              width: _isHighContrastMode ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _isHighContrastMode
                          ? (_isDarkMode ? Colors.yellow : Colors.black)
                          : _isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    icon,
                    color: textColor,
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (period != null)
                Text(
                  period,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white60 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              if (trend != null)
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp
                          ? (_isHighContrastMode ? Colors.yellow : Colors.green)
                          : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        color: isUp
                            ? (_isHighContrastMode
                                ? Colors.yellow
                                : Colors.green)
                            : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(AsyncValue<Map<String, double>> payments) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isHighContrastMode
              ? (_isDarkMode ? Colors.yellow : Colors.black)
              : Colors.blue.withOpacity(0.3),
          width: _isHighContrastMode ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isHighContrastMode
                  ? (_isDarkMode ? Colors.yellow : Colors.black)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: payments.when(
              data: (data) => _buildPieChart(data),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Failed to load revenue data')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final dailyAmount = data['daily'] ?? 0;
    final weeklyAmount = data['weekly'] ?? 0;
    final monthlyAmount = data['monthly'] ?? 0;
    final totalAmount = data['total'] ?? 0;

    if (totalAmount <= 0) {
      return Center(
        child: Text(
          'No revenue data available',
          style: TextStyle(
            color: _isDarkMode ? Colors.white60 : Colors.black45,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: _isHighContrastMode ? Colors.yellow : Colors.blue,
                  value: dailyAmount,
                  title:
                      '${((dailyAmount / totalAmount) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isHighContrastMode ? Colors.black : Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: _isHighContrastMode ? Colors.white : Colors.green,
                  value: weeklyAmount,
                  title:
                      '${((weeklyAmount / totalAmount) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isHighContrastMode ? Colors.black : Colors.white,
                  ),
                ),
                PieChartSectionData(
                  color: _isHighContrastMode ? Colors.cyan : Colors.purple,
                  value: monthlyAmount,
                  title:
                      '${((monthlyAmount / totalAmount) * 100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isHighContrastMode ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem('Daily', Colors.blue, dailyAmount, totalAmount),
              const SizedBox(height: 8),
              _buildLegendItem(
                  'Weekly', Colors.green, weeklyAmount, totalAmount),
              const SizedBox(height: 8),
              _buildLegendItem(
                  'Monthly', Colors.purple, monthlyAmount, totalAmount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(
      String label, Color color, double amount, double total) {
    final percentage = total > 0 ? (amount / total * 100) : 0;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _isHighContrastMode
                ? (label == 'Daily'
                    ? Colors.yellow
                    : label == 'Weekly'
                        ? Colors.white
                        : Colors.cyan)
                : color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label (${percentage.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 12,
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAdWidget({double? maxWidth}) {
    return Center(
      child: _adManager.getBannerAdWidget(
        maxWidth: maxWidth ?? MediaQuery.of(context).size.width - 32,
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isHighContrastMode ? Colors.yellow : null,
            ),
          ),
        ),
        GridView.count(
          key: _quickActionsKey,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            _buildQuickActionItem(
              'Add\nCustomer',
              Icons.person_add,
              Colors.green,
              '/add-customer',
              category: 'customer',
            ),
            _buildQuickActionItem(
              'View\nPayments',
              Icons.payments,
              Colors.blue,
              '/payments',
              category: 'finance',
            ),
            _buildQuickActionItem(
              'Expiring\nSoon',
              Icons.timer,
              Colors.orange,
              '/expiring-subscriptions',
              category: 'customer',
            ),
            _buildQuickActionItem(
              'Inactive\nUsers',
              Icons.person_off,
              Colors.red,
              '/inactive-customers',
              category: 'customer',
            ),
            _buildQuickActionItem(
              'Log\nDowntime',
              Icons.wifi_off,
              Colors.grey,
              '/downtime-input',
              category: 'operations',
            ),
            _buildQuickActionItem(
              'Billing\nCycles',
              Icons.date_range,
              Colors.teal,
              '/billing-cycles',
              category: 'finance',
            ),
            _buildQuickActionItem(
              'Retention\nStats',
              Icons.insights,
              Colors.purple,
              '/retention',
              category: 'analytics',
            ),
            _buildQuickActionItem(
              'Scheduled\nReminders',
              Icons.notifications,
              Colors.amber,
              '/scheduled-reminders',
              category: 'operations',
            ),
            _buildQuickActionItem(
              'Settings',
              Icons.settings,
              Colors.blueGrey,
              '/settings',
              category: 'system',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(
      String title, IconData icon, Color color, String route,
      {required String category}) {
    final backgroundColor = _isHighContrastMode
        ? (_isDarkMode ? Colors.black : Colors.white)
        : (_isDarkMode ? Colors.grey[850] : Colors.white);

    final borderColor = _isHighContrastMode
        ? (_isDarkMode ? Colors.yellow : Colors.black)
        : color.withOpacity(0.3);

    final iconColor = _isHighContrastMode
        ? (_isDarkMode ? Colors.yellow : Colors.black)
        : color;

    return Semantics(
      button: true,
      label: title.replaceAll('\n', ' '),
      onTapHint: "Navigate to ${title.replaceAll('\n', ' ')}",
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: borderColor,
              width: _isHighContrastMode ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isHighContrastMode
                      ? (_isDarkMode ? Colors.yellow : Colors.black)
                      : (_isDarkMode ? Colors.white : Colors.black87),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSubscriptionsSection(
      AsyncValue<List<Customer>> expiringSubscriptions) {
    return expiringSubscriptions.when(
      data: (customers) {
        if (customers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expiring Soon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isHighContrastMode ? Colors.yellow : null,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/expiring-subscriptions'),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: _isHighContrastMode
                          ? (_isDarkMode ? Colors.yellow : Colors.black)
                          : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: _isHighContrastMode
                      ? (_isDarkMode ? Colors.yellow : Colors.black)
                      : Colors.orange.withOpacity(0.3),
                  width: _isHighContrastMode ? 2 : 1,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: customers.length > 3 ? 3 : customers.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  final daysLeft = customer.subscriptionEnd
                      .difference(DateTime.now())
                      .inDays;
                  final hoursLeft = customer.subscriptionEnd
                          .difference(DateTime.now())
                          .inHours %
                      24;

                  String timeLeft;
                  Color timeColor;

                  if (daysLeft < 0) {
                    timeLeft = 'Expired';
                    timeColor =
                        _isHighContrastMode ? Colors.yellow : Colors.red;
                  } else if (daysLeft == 0) {
                    timeLeft = 'Today (${hoursLeft}h left)';
                    timeColor =
                        _isHighContrastMode ? Colors.yellow : Colors.orange;
                  } else {
                    timeLeft = '$daysLeft days left';
                    timeColor =
                        _isHighContrastMode ? Colors.yellow : Colors.amber;
                  }

                  return Semantics(
                    button: true,
                    label:
                        "Expiring subscription for ${customer.name}, ${timeLeft}",
                    onTapHint: "View details",
                    child: ListTile(
                      title: Text(
                        customer.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isHighContrastMode
                              ? (_isDarkMode ? Colors.yellow : Colors.black)
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${customer.planType.name} plan',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeLeft,
                            style: TextStyle(
                              color: timeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/customer/${customer.id}',
                        arguments: customer,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/add-customer'),
      icon: const Icon(Icons.person_add),
      label: const Text('Add Customer'),
      tooltip: 'Add a new customer',
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: _isHighContrastMode ? Colors.yellow : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _isHighContrastMode ? Colors.yellow : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatefulWidget {
  final bool isDarkMode;

  const _AnimatedBackground({
    required this.isDarkMode,
  });

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GradientPainter(
            animation: _controller,
            isDarkMode: widget.isDarkMode,
          ),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDarkMode;

  _GradientPainter({
    required this.animation,
    required this.isDarkMode,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Offset.zero & size;

    // Colors based on dark/light mode
    final List<Color> colors = isDarkMode
        ? [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF121212)]
        : [Color(0xFF90CAF9), Color(0xFFBBDEFB), Color(0xFFE3F2FD)];

    final gradient = RadialGradient(
      center: Alignment(
        0.6 * sin(animation.value * pi * 2),
        0.6 * cos(animation.value * pi * 2),
      ),
      colors: colors,
      stops: const [0.0, 0.5, 1.0],
      radius: 1.5,
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.isDarkMode != isDarkMode;
}
