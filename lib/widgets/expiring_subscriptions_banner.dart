import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/subscription_provider.dart';

class ExpiringSubscriptionsBanner extends ConsumerStatefulWidget {
  const ExpiringSubscriptionsBanner({super.key});

  @override
  ConsumerState<ExpiringSubscriptionsBanner> createState() =>
      _ExpiringSubscriptionsBannerState();
}

class _ExpiringSubscriptionsBannerState
    extends ConsumerState<ExpiringSubscriptionsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(
      begin: -50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiringSubscriptions = ref.watch(expiringSubscriptionsProvider);

    return expiringSubscriptions.when(
      data: (customers) {
        if (customers.isEmpty) return const SizedBox.shrink();

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.1),
                            Colors.deepOrange.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: MaterialBanner(
                        backgroundColor: Colors.transparent,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiring Subscriptions',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${customers.length} subscriptions expiring soon',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        leading: ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                              ).createShader(bounds),
                          child: const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed:
                                () => Navigator.pushNamed(
                                  context,
                                  '/expiring-subscriptions',
                                ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('VIEW ALL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
