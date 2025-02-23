import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/ad_manager.dart';
import '../services/subscription_widget_service.dart';
import 'login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AdManager _adManager = AdManager();
  String _filter = 'This Month'; // Default filter
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.forward();
    // Initialize ads
    _initializeAds();

    // Schedule periodic interstitial ad preloading
    Timer.periodic(const Duration(minutes: 2), (timer) {
      _adManager.initializeInterstitialAd();
    });
  }

  Future<void> _initializeAds() async {
    await _adManager.initializeBannerAd();
    await _adManager.initializeInterstitialAd();
    await _adManager.initializeRewardedAd();
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
    if (authService.currentUser == null) return const LoginScreen();
    ref.invalidate(expiringSubscriptionsProvider);
    ref.invalidate(activeCustomersProvider);
    ref.invalidate(paymentSummaryProvider);
    // ref.watch(databaseProvider).syncPendingChanges();
    // ref.watch(databaseProvider).scheduleNotifications();
    // final isSyncing = ref.watch(syncingProvider);
    final activeCustomers =
        ref.watch(activeCustomersProvider); // Watch the FutureProvider
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);
    ref.listen(expiringSubscriptionsProvider, (previous, next) {
      next.whenData((customers) {
        activeCustomers.whenData((activeCount) {
          ref.watch(paymentSummaryProvider).whenData((summary) {
            print(
                'Sending to widget: expiring=${customers.length}, active=${activeCount.length}, revenue=${summary['total'] ?? 0.0}');
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
      backgroundColor: const Color(0xFF1A1A1A),
      extendBodyBehindAppBar: true,
      appBar: _GlassmorphicAppBar(
        title: 'WiFi Manager',
        onNotificationTap: () =>
            Navigator.pushNamed(context, '/scheduled-reminders'),
      ),
      body: Stack(
        children: [
          _AnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterBar(),
                        const SizedBox(height: 16),
                        _buildStatsSection(activeCustomers,
                            expiringSubscriptions), // Pass as parameters
                        const SizedBox(height: 16),
                        _adManager.getBannerAdWidget(
                            maxWidth: MediaQuery.of(context).size.width - 24),
                        const SizedBox(height: 16),
                        _buildQuickActions(),
                        const SizedBox(height: 16),
                        _buildActionButton('Downtime', CupertinoIcons.clock,
                            Colors.red, '/downtime-input'),
                        const SizedBox(height: 16),
                        _adManager.getBannerAdWidget(
                            maxWidth: MediaQuery.of(context).size.width - 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['Today', 'This Week', 'This Month']
            .map((filter) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = filter);
                    },
                    selectedColor: Colors.blueAccent.withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    labelStyle: TextStyle(
                        color:
                            _filter == filter ? Colors.white : Colors.white70),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<List<Customer>> activeCustomers,
      AsyncValue<List<Customer>> expiringSubscriptions) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Active', activeCustomers, Colors.green, '/customers')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard('Expiring Today', expiringSubscriptions,
                    Colors.red, '/expiring-subscriptions')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Revenue',
                    ref.watch(paymentSummaryProvider),
                    Colors.blue,
                    '/payments')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard('New This Week', activeCustomers,
                    Colors.purple, '/customers')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, AsyncValue data, Color color, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: data.when(
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                title == 'Revenue'
                    ? 'UGX ${value['total']?.toStringAsFixed(0) ?? '0'}'
                    : title == 'New This Week'
                        ? '${value.where((Customer customer) => customer.subscriptionStart.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length}'
                        : title == 'Expiring Today'
                            ? '${value.where((Customer customer) => customer.subscriptionEnd.difference(DateTime.now()).inDays <= 0).length}'
                            : '${value.length}',
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              if (title == 'Revenue')
                Text('Monthly',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildActionButton('Add Customer', CupertinoIcons.person_add_solid,
            Colors.green, '/add-customer'),
        _buildActionButton('Payments', CupertinoIcons.money_dollar_circle_fill,
            Colors.blue, '/payments'),
        _buildActionButton('Customers', CupertinoIcons.person_2_fill,
            Colors.purple, '/customers'),
        _buildActionButton(
            'Expiring',
            CupertinoIcons.exclamationmark_triangle_fill,
            Colors.orange,
            '/expiring-subscriptions'),
      ],
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color.withOpacity(0.5)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

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

    // Create animated gradient positions
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
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.bell,
                        color: Colors.white,
                      ),
                      onPressed: onNotificationTap,
                    ),
                    expiringSubscriptions.when(
                      data: (customers) {
                        if (customers.isEmpty) return const SizedBox.shrink();
                        return Positioned(
                          right: 8,
                          top: 8,
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
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassmorphicActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _GlassmorphicActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_GlassmorphicActionCard> createState() =>
      _GlassmorphicActionCardState();
}

class _GlassmorphicActionCardState extends State<_GlassmorphicActionCard>
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
    return MouseRegion(
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
                    // Animated gradient background
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
                    // Content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.icon,
                            size: 32,
                            color: Colors.white.withOpacity(0.9),
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
    );
  }
}
