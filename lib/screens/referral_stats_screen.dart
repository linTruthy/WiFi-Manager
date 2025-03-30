import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/models/customer.dart';
import '../database/models/referral_stats.dart';
import '../providers/referral_stats_provider.dart';
import '../providers/customer_provider.dart';

class ReferralStatsScreen extends ConsumerStatefulWidget {
  final String referrerId;
  const ReferralStatsScreen({super.key, required this.referrerId});

  @override
  ConsumerState<ReferralStatsScreen> createState() =>
      _ReferralStatsScreenState();
}

class _ReferralStatsScreenState extends ConsumerState<ReferralStatsScreen> {
  bool _isLoading = false;
  Customer? _referrer;
  String _timeFilter = 'All Time';
  bool _showReferralGuide = false;

  @override
  void initState() {
    super.initState();
    _loadReferrerDetails();
  }

  Future<void> _loadReferrerDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customerAsync = ref.read(customerProvider(widget.referrerId));
      final customer = await customerAsync.value;
      setState(() {
        _referrer = customer;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer details: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareReferralCode() {
    if (_referrer == null) return;

    Share.share(
      'Join Truthy WiFi using my referral code: ${_referrer!.referralCode}\n\n'
      'Benefits:\n'
      '• 7 free days for monthly plan subscribers\n'
      '• 3 free days for weekly plan subscribers\n'
      '• 1 free day for daily plan subscribers',
      subject: 'Join Truthy WiFi with my referral code',
    );
  }

  void _copyReferralCode() {
    if (_referrer == null) return;

    Clipboard.setData(ClipboardData(text: _referrer!.referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied to clipboard')),
    );
  }

  List<ReferralStats> _filterReferrals(List<ReferralStats> referrals) {
    final now = DateTime.now();

    switch (_timeFilter) {
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return referrals
            .where((referral) => referral.referralDate.isAfter(startOfMonth))
            .toList();

      case 'Last 3 Months':
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return referrals
            .where((referral) => referral.referralDate.isAfter(threeMonthsAgo))
            .toList();

      case 'This Year':
        final startOfYear = DateTime(now.year, 1, 1);
        return referrals
            .where((referral) => referral.referralDate.isAfter(startOfYear))
            .toList();

      case 'All Time':
      default:
        return referrals;
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralStatsAsync =
        ref.watch(referralStatsProvider(widget.referrerId));
    final totalReferralsAsync =
        ref.watch(totalReferralsProvider(widget.referrerId));
    final totalRewardDurationAsync =
        ref.watch(totalRewardDurationProvider(widget.referrerId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _referrer != null
            ? Text('${_referrer!.name}\'s Referrals')
            : const Text('Referral Stats'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Time Filter',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _timeFilter = value;
              });
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem('All Time', Icons.date_range),
              _buildPopupMenuItem('This Month', Icons.calendar_today),
              _buildPopupMenuItem('Last 3 Months', Icons.calendar_view_month),
              _buildPopupMenuItem('This Year', Icons.calendar_view_week),
            ],
          ),
          IconButton(
            icon: Icon(_showReferralGuide ? Icons.help : Icons.help_outline),
            tooltip: 'Referral Guide',
            onPressed: () {
              setState(() {
                _showReferralGuide = !_showReferralGuide;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.refresh(referralStatsProvider(widget.referrerId));
                ref.refresh(totalReferralsProvider(widget.referrerId));
                ref.refresh(totalRewardDurationProvider(widget.referrerId));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Referral code card
                    if (_referrer != null) _buildReferralCodeCard(theme),

                    // Info banner
                    if (_showReferralGuide) ...[
                      const SizedBox(height: 16),
                      _buildReferralGuide(theme),
                    ],

                    const SizedBox(height: 16),

                    // Filter indicator
                    if (_timeFilter != 'All Time')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            Chip(
                              label: Text('Filter: $_timeFilter'),
                              deleteIcon: const Icon(Icons.clear, size: 18),
                              onDeleted: () =>
                                  setState(() => _timeFilter = 'All Time'),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                            ),
                          ],
                        ),
                      ),

                    // Stats cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Referrals',
                            totalReferralsAsync,
                            Icons.people,
                            theme.colorScheme.primary,
                            suffix: 'customers',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Free Days Earned',
                            totalRewardDurationAsync,
                            Icons.card_giftcard,
                            Colors.purple,
                            valueTransform: (duration) => '${duration.inDays}',
                            suffix: 'days',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Charts section
                    referralStatsAsync.when(
                      data: (referrals) {
                        if (referrals.isEmpty) {
                          return _buildEmptyState(theme);
                        }

                        final filteredReferrals = _filterReferrals(referrals);
                        if (filteredReferrals.isEmpty) {
                          return Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.filter_list_off,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No referrals found for $_timeFilter',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () => setState(
                                        () => _timeFilter = 'All Time'),
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Clear Filter'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChartSection(filteredReferrals, theme),
                            const SizedBox(height: 24),
                            Text(
                              'Referral History',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            _buildReferralList(filteredReferrals, theme),
                          ],
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error loading referrals: $e'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => ref.refresh(
                                    referralStatsProvider(widget.referrerId)),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _referrer != null
          ? FloatingActionButton.extended(
              onPressed: _shareReferralCode,
              icon: const Icon(Icons.share),
              label: const Text('Share Referral Code'),
              tooltip: 'Share your referral code',
            )
          : null,
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: _timeFilter == value
                  ? Theme.of(context).colorScheme.primary
                  : null),
          const SizedBox(width: 8),
          Text(value),
          if (_timeFilter == value)
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

  Widget _buildReferralCodeCard(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Your Referral Code',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _referrer!.referralCode,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with customers',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: 'Copy referral code',
                  button: true,
                  child: OutlinedButton.icon(
                    onPressed: _copyReferralCode,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 16),
                Semantics(
                  label: 'Share referral code',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: _shareReferralCode,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralGuide(ThemeData theme) {
    return Card(
      elevation: 2,
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'How Referrals Work',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showReferralGuide = false;
                    });
                  },
                  tooltip: 'Close guide',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuideItem(
              '1. Share your referral code',
              'Send your code to friends or customers who want to sign up',
              Icons.share,
              theme,
            ),
            _buildGuideItem(
              '2. They sign up using your code',
              'New customers enter your code when registering',
              Icons.person_add,
              theme,
            ),
            _buildGuideItem(
              '3. You earn free days',
              'Monthly: 7 days, Weekly: 3 days, Daily: 1 day',
              Icons.card_giftcard,
              theme,
            ),
            _buildGuideItem(
              '4. Free days are automatically added',
              'Your subscription is extended immediately',
              Icons.auto_awesome,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(
      String title, String description, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSecondaryContainer.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        theme.colorScheme.onSecondaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard<T>(
    String title,
    AsyncValue<T> asyncValue,
    IconData icon,
    Color color, {
    String Function(T)? valueTransform,
    String? suffix,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: asyncValue.when(
                data: (value) {
                  final displayValue = valueTransform != null
                      ? valueTransform(value)
                      : value.toString();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        displayValue,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (suffix != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            suffix,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Text(
                  'Error',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/no_referrals.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'No Referrals Yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Share your referral code to start earning free days',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _shareReferralCode,
              icon: const Icon(Icons.share),
              label: const Text('Share Your Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<ReferralStats> referrals, ThemeData theme) {
    // Group referrals by month for the chart
    final referralsByMonth = <DateTime, int>{};
    final rewardsByMonth = <DateTime, int>{};

    for (final referral in referrals) {
      final month =
          DateTime(referral.referralDate.year, referral.referralDate.month, 1);
      referralsByMonth[month] = (referralsByMonth[month] ?? 0) + 1;
      rewardsByMonth[month] = (rewardsByMonth[month] ?? 0) +
          (referral.rewardDurationMillis ~/ Duration.millisecondsPerDay);
    }

    // Sort by date
    final sortedMonths = referralsByMonth.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // Limit to last 6 months for readability
    if (sortedMonths.length > 6) {
      sortedMonths.removeRange(0, sortedMonths.length - 6);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Referral Performance',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Text(
                'Referrals by Month',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: sortedMonths.isEmpty
                    ? const Center(child: Text('Not enough data for chart'))
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (referralsByMonth.values.isEmpty
                                  ? 0
                                  : referralsByMonth.values.reduce(max)) *
                              1.2,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10)),
                                reservedSize: 28,
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < sortedMonths.length) {
                                    final month = sortedMonths[value.toInt()];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        DateFormat('MMM\nyy').format(month),
                                        style: const TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                                reservedSize: 30,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            sortedMonths.length,
                            (index) {
                              final month = sortedMonths[index];
                              final count = referralsByMonth[month] ?? 0;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: count.toDouble(),
                                    color: theme.colorScheme.primary,
                                    width: 20,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          gridData: const FlGridData(show: false),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Text(
                'Reward Days Earned by Month',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: sortedMonths.isEmpty
                    ? const Center(child: Text('Not enough data for chart'))
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10)),
                                reservedSize: 28,
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < sortedMonths.length) {
                                    final month = sortedMonths[value.toInt()];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        DateFormat('MMM\nyy').format(month),
                                        style: const TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                                reservedSize: 30,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots:
                                  List.generate(sortedMonths.length, (index) {
                                final month = sortedMonths[index];
                                final rewards = rewardsByMonth[month] ?? 0;
                                return FlSpot(
                                    index.toDouble(), rewards.toDouble());
                              }),
                              isCurved: true,
                              color: Colors.purple,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.purple.withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralList(List<ReferralStats> referrals, ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: referrals.length,
      itemBuilder: (context, index) {
        final referral = referrals[index];
        final rewardDays =
            referral.rewardDurationMillis ~/ Duration.millisecondsPerDay;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar date visual
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM').format(referral.referralDate),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        referral.referralDate.day.toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        referral.referralDate.year.toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Referral details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Customer?>(
                        future:
                            _loadReferredCustomer(referral.referredCustomerId),
                        builder: (context, snapshot) {
                          final customerName = snapshot.data?.name ??
                              'Customer ${referral.referredCustomerId.substring(0, 6)}';

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: theme.textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.card_giftcard,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+$rewardDays days',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMMM d, y')
                                .format(referral.referralDate),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ID: ${referral.id.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Customer?> _loadReferredCustomer(String customerId) async {
    try {
      final customerAsync = ref.read(customerProvider(customerId));
      return await customerAsync.value;
    } catch (e) {
      return null;
    }
  }
}
