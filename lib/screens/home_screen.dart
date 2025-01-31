import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_customer_trend_provider.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/syncing_provider.dart';
import '../widgets/expiring_subscriptions_banner.dart';
import 'login_screen.dart';
import 'scheduled_reminders_screen.dart';

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
  }

  @override
  void dispose() {
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
    
    ref.watch(notificationSchedulerProvider);
    ref.read(databaseProvider).syncPendingChanges();
    final isSyncing = ref.watch(syncingProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      extendBodyBehindAppBar: true,
      appBar: _GlassmorphicAppBar(
        title: 'Truthy WiFi Manager',
        onNotificationTap: () {
          // Handle notifications
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
          _AnimatedBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildMainContent(),
              ),
            ),
          ),
          if (isSyncing)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Syncing...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExpiringSubscriptionsBanner(),
            const SizedBox(height: 24),
            _AnimatedStatsSection(ref: ref),
            const SizedBox(height: 24),
            _buildSectionHeader('Quick Actions'),
            const SizedBox(height: 16),
            _AnimatedActionsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return TweenAnimationBuilder<double>(
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
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
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

class _AnimatedStatsSection extends StatelessWidget {
  final WidgetRef ref;

  const _AnimatedStatsSection({required this.ref});

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
            child: Row(
              children: [
                Expanded(
                  child: _GlassmorphicStatsCard(
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
                          data:
                              (customers) => trendAsync.when(
                                data:
                                    (trend) => _AnimatedStatContent(
                                      value: customers.length.toString(),
                                      trend:
                                          '${trend.toStringAsFixed(1)}% this month',
                                    ),
                                loading:
                                    () => const CircularProgressIndicator(),
                                error: (_, __) => const Icon(Icons.error),
                              ),
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GlassmorphicStatsCard(
                    title: 'Expiring Soon',
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    iconColor: Colors.orange,
                    content: Consumer(
                      builder: (context, ref, child) {
                        final expiringAsync = ref.watch(
                          expiringCustomersProvider,
                        );
                        return expiringAsync.when(
                          data:
                              (customers) => _AnimatedStatContent(
                                value: customers.length.toString(),
                                trend: 'Next 3 days',
                              ),
                          loading: () => const CircularProgressIndicator(),
                          error: (_, __) => const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlassmorphicStatsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;

  const _GlassmorphicStatsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
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
    );
  }
}

class _AnimatedStatContent extends StatelessWidget {
  final String value;
  final String trend;

  const _AnimatedStatContent({required this.value, required this.trend});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              this.value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24 * value,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: TextStyle(
                color: trend.startsWith('-') ? Colors.red : Colors.green,
                fontSize: 12 * value,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildAnimatedActionCard(
          index: 0,
          title: 'Add Customer',
          icon: CupertinoIcons.person_add_solid,
          gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          onTap: () => Navigator.pushNamed(context, '/add-customer'),
        ),
        _buildAnimatedActionCard(
          index: 1,
          title: 'Recent Payments',
          icon: CupertinoIcons.money_dollar_circle_fill,
          gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
          onTap: () => Navigator.pushNamed(context, '/payments'),
        ),
        _buildAnimatedActionCard(
          index: 2,
          title: 'View Customers',
          icon: CupertinoIcons.person_2_fill,
          gradient: const [Color(0xFF7E57C2), Color(0xFF4527A0)],
          onTap: () => Navigator.pushNamed(context, '/customers'),
        ),
        _buildAnimatedActionCard(
          index: 3,
          title: 'Expiring',
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          gradient: const [Color(0xFFFF7043), Color(0xFFE64A19)],
          onTap: () => Navigator.pushNamed(context, '/expiring-subscriptions'),
        ),
      ],
    );
  }

  Widget _buildAnimatedActionCard({
    required int index,
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
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
            child: _GlassmorphicActionCard(
              title: title,
              icon: icon,
              gradient: gradient,
              onTap: onTap,
            ),
          ),
        );
      },
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
