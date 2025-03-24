import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truthy_wifi_manager/database/repository/database_repository.dart';
import 'package:truthy_wifi_manager/screens/home/widgets/syncing_indicator.dart';
import '../../providers/active_customer_trend_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/notification_schedule_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/syncing_provider.dart';
import '../../services/ad_manager.dart';
import '../../services/subscription_widget_service.dart';
import '../../widgets/expiring_subscriptions_banner.dart';
import '../auth/login_screen.dart';
import '../scheduled_reminders_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final AdManager _adManager = AdManager();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _initializeAds();
    _refreshData();
    
    Timer.periodic(const Duration(minutes: 2), (timer) {
      _adManager.initializeInterstitialAd();
    });
  }
  
  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd();
    await _adManager.initializeInterstitialAd();
    await _adManager.initializeRewardedAd();
  }
  
  Future<void> _refreshData() async {
    ref.invalidate(recentPaymentsProvider);
    ref.invalidate(paymentSummaryProvider);
    ref.invalidate(filteredPaymentsProvider);
    ref.invalidate(activeCustomersProvider);
    ref.invalidate(expiringCustomersProvider);
    ref.invalidate(syncingProvider);
    ref.invalidate(expiringSubscriptionsProvider);
    
    ref.watch(notificationSchedulerProvider);
    ref.watch(scheduledNotificationsProvider);
    
    await ref.read(databaseProvider).syncPendingChanges();
    await ref.read(databaseProvider).scheduleNotifications();
  }
  
  @override
  void dispose() {
    _adManager.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) {
      return const LoginScreen();
    }
    
    final isSyncing = ref.watch(syncingProvider);
    final activeCustomers = ref.watch(activeCustomersProvider);
    
    // Update widget data when customers change
    ref.listen(expiringSubscriptionsProvider, (previous, next) {
      next.whenData((customers) {
        activeCustomers.whenData((activeCount) {
          SubscriptionWidgetService.updateWidgetData(
            customers,
            activeCount.length,
          );
        });
      });
    });
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      extendBodyBehindAppBar: true,
      appBar: _GlassmorphicAppBar(
        title: 'Truthy WiFi Manager',
        onNotificationTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScheduledRemindersScreen(),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          // Animated background
          _AnimatedBackground(),
          
          // Main content
          SafeArea(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshData,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.black38,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildMainContent(),
                ),
              ),
            ),
          ),
          
          // Syncing indicator
          if (isSyncing)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SyncingIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expiring subscriptions banner
            const ExpiringSubscriptionsBanner(),
            const SizedBox(height: 24),
            
            // Stats section
            _StatsSection(ref: ref),
            const SizedBox(height: 24),
            
            // Quick actions section
            _buildSectionHeader('Quick Actions'),
            const SizedBox(height: 16),
            _ActionsGrid(),
            
            // Ad banner
            const SizedBox(height: 24),
            _AdBanner(adManager: _adManager),
            
            // Extra bottom padding for better scroll experience
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Semantics(
      header: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final WidgetRef ref;
  
  const _StatsSection({required this.ref});
  
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Active Customers',
                        icon: CupertinoIcons.person_2_fill,
                        iconColor: Colors.blue,
                        content: Consumer(
                          builder: (context, ref, child) {
                            final customersAsync = ref.watch(
                              activeCustomersProvider,
                            );
                            final trendAsync = ref.watch(
                              activeCustomerTrendProvider,
                            );
                            return customersAsync.when(
                              data: (customers) => trendAsync.when(
                                data: (trend) => _StatContent(
                                  value: customers.length.toString(),
                                  trend: '${trend.toStringAsFixed(1)}% this month',
                                  isPositive: trend >= 0,
                                ),
                                loading: () => _StatLoadingPlaceholder(),
                                error: (_, __) => _StatErrorPlaceholder(),
                              ),
                              loading: () => _StatLoadingPlaceholder(),
                              error: (_, __) => _StatErrorPlaceholder(),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Expiring Soon',
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        iconColor: Colors.orange,
                        content: Consumer(
                          builder: (context, ref, child) {
                            final expiringAsync = ref.watch(
                              expiringCustomersProvider,
                            );
                            return expiringAsync.when(
                              data: (customers) => _StatContent(
                                value: customers.length.toString(),
                                trend: 'Next 3 days',
                                isPositive: false,
                                showWarningIfHigher: true,
                              ),
                              loading: () => _StatLoadingPlaceholder(),
                              error: (_, __) => _StatErrorPlaceholder(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  
  const _StatCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
  });
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      value: 'Statistic card',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatContent extends StatelessWidget {
  final String value;
  final String trend;
  final bool isPositive;
  final bool showWarningIfHigher;
  
  const _StatContent({
    required this.value,
    required this.trend,
    this.isPositive = true,
    this.showWarningIfHigher = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final warningThreshold = 3; // Show warning if value is > 3
    final int? valueAsInt = int.tryParse(value);
    final shouldShowWarning = showWarningIfHigher && 
                             valueAsInt != null && 
                             valueAsInt > warningThreshold;
    
    final trendColor = isPositive ? Colors.green : Colors.redAccent;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24 * animValue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (shouldShowWarning) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20 * animValue,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: TextStyle(
                color: trendColor,
                fontSize: 12 * animValue,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatLoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 24,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _StatErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Error loading data',
              style: TextStyle(
                color: Colors.red.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            final refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
            refreshIndicatorKey.currentState?.show();
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _ActionsGrid extends StatelessWidget {
  final List<ActionItem> _actions = [
    ActionItem(
      title: 'Add Customer',
      icon: CupertinoIcons.person_add_solid,
      gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      route: '/add-customer',
    ),
    ActionItem(
      title: 'Recent Payments',
      icon: CupertinoIcons.money_dollar_circle_fill,
      gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
      route: '/payments',
    ),
    ActionItem(
      title: 'View Customers',
      icon: CupertinoIcons.person_2_fill,
      gradient: const [Color(0xFF7E57C2), Color(0xFF4527A0)],
      route: '/customers',
    ),
    ActionItem(
      title: 'Expiring',
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
      route: '/expiring-subscriptions',
    ),
    ActionItem(
      title: 'Down Time',
      icon: CupertinoIcons.clock_solid,
      gradient: const [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
      route: '/downtime-input',
    ),
  ];

  final AdManager _adManager = AdManager();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        return _buildAnimatedActionCard(
          context: context,
          index: index,
          item: _actions[index],
        );
      },
    );
  }

  Widget _buildAnimatedActionCard({
    required BuildContext context,
    required int index,
    required ActionItem item,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: _ActionCard(
              title: item.title,
              icon: item.icon,
              gradient: item.gradient,
              onTap: () => _handleActionTap(context, item.route),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleActionTap(BuildContext context, String route) async {
    HapticFeedback.lightImpact();
    if (Random().nextDouble() < 0.3) {
      final bool adShown = await _adManager.showInterstitialAd();
      if (!adShown) {
        Navigator.pushNamed(context, route);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    Navigator.pushNamed(context, route);
  }
}

class ActionItem {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String route;

  ActionItem({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.route,
  });
}

class _ActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
      if (isHovered) {
        _hoverController.forward();
      } else {
        _hoverController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title} button',
      child: MergeSemantics(
        child: MouseRegion(
          onEnter: (_) => _onHoverChanged(true),
          onExit: (_) => _onHoverChanged(false),
          child: GestureDetector(
            onTapDown: (_) => _onHoverChanged(true),
            onTapUp: (_) => _onHoverChanged(false),
            onTapCancel: () => _onHoverChanged(false),
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(scale: _scaleAnimation.value, child: child);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.gradient[0].withOpacity(0.7),
                          widget.gradient[1].withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.1),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradient[0].withOpacity(0.3),
                          blurRadius: _isHovered ? 12 : 8,
                          spreadRadius: _isHovered ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (_isHovered)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeInOut,
                            left: _isHovered ? -100 : 0,
                            top: _isHovered ? -100 : 0,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    widget.gradient[0].withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.icon,
                                size: 32,
                                color: Colors.white.withOpacity(0.9),
                                semanticLabel: null, // Semantics added to parent
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdBanner extends StatelessWidget {
  final AdManager adManager;
  
  const _AdBanner({required this.adManager});
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Advertisement',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: adManager.getBannerAdWidget(
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassmorphicAppBar extends ConsumerWidget
    implements PreferredSizeWidget {
  final String title;
  final VoidCallback onNotificationTap;
  const _GlassmorphicAppBar({
    required this.title,
    required this.onNotificationTap,
  });
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            border: const Border(
              bottom: BorderSide(color: Colors.white10, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Stack(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Notifications',
                      child: IconButton(
                        icon: const Icon(
                          CupertinoIcons.bell,
                          color: Colors.white,
                        ),
                        onPressed: onNotificationTap,
                        tooltip: 'View scheduled reminders',
                      ),
                    ),
                    expiringSubscriptions.when(
                      data: (customers) {
                        if (customers.isEmpty) return const SizedBox.shrink();
                        return Positioned(
                          right: 8,
                          top: 8,
                          child: Semantics(
                            label: '${customers.length} notifications',
                            excludeSemantics: true,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      customers.length.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Logout',
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await _showLogoutConfirmation(context, ref);
                    },
                    tooltip: 'Logout',
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _showLogoutConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

// Keep the existing _AnimatedBackground class
class _AnimatedBackground extends StatefulWidget {
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
      duration: const Duration(seconds: 10),
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
          painter: _GradientPainter(animation: _controller),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Animation<double> animation;
  _GradientPainter({required this.animation}) : super(repaint: animation);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: Alignment(
        0.7 * sin(animation.value * pi * 2),
        0.7 * cos(animation.value * pi * 2),
      ),
      colors: const [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF1A1A1A)],
      stops: const [0.0, 0.5, 1.0],
      radius: 1.5,
    );
    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
  @override
  bool shouldRepaint(_GradientPainter oldDelegate) => true;
}