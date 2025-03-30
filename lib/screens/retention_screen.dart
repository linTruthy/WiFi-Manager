import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/retention_provider.dart';

class RetentionScreen extends ConsumerStatefulWidget {
  const RetentionScreen({super.key});
  @override
  ConsumerState<RetentionScreen> createState() => _RetentionScreenState();
}

class _RetentionScreenState extends ConsumerState<RetentionScreen> {
  DateTimeRange? _selectedRange;
  bool _showHelp = false;
  final _dateRangeKey = GlobalKey();
  final _retentionCardKey = GlobalKey();
  final _churnCardKey = GlobalKey();
  final _customersCardKey = GlobalKey();
  final _actionsCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final retentionAsync = ref.watch(retentionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Retention Insights'),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Learn about retention metrics',
              child: InkWell(
                onTap: () => setState(() => _showHelp = !_showHelp),
                child: Icon(
                  _showHelp ? Icons.help : Icons.help_outline,
                  color: _showHelp ? theme.colorScheme.primary : null,
                  semanticLabel: 'Toggle help information',
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Date range picker button
          Semantics(
            label: 'Select custom date range',
            button: true,
            child: IconButton(
              key: _dateRangeKey,
              icon: const Icon(Icons.date_range),
              tooltip: 'Select custom date range',
              onPressed: () => _selectDateRange(context),
            ),
          ),
          // Refresh button
          Semantics(
            label: 'Refresh data',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh data',
              onPressed: () => ref.refresh(retentionProvider),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(retentionProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: retentionAsync.when(
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Help banner - displays when help mode is toggled
                  if (_showHelp) _buildHelpBanner(context),

                  // Date range indicator
                  _buildDateRangeIndicator(context),

                  const SizedBox(height: 16),

                  // Key metrics summary
                  _buildKeyMetricsSummary(context, data),

                  const SizedBox(height: 16),

                  // Main metrics section with visualization
                  _buildMetricsSection(context, data),

                  const SizedBox(height: 16),

                  // Customer activity metrics
                  _buildCustomerActivitySection(context, data),

                  const SizedBox(height: 16),

                  // Action buttons section
                  _buildActionSection(context),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading retention data...')
                    ],
                  ),
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load retention data',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: TextStyle(color: Colors.red[300]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      onPressed: () => ref.refresh(retentionProvider),
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

  Widget _buildHelpBanner(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Understanding Retention Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHelpItem(context, 'Retention Rate',
                'Percentage of customers who remain active out of the total customer base'),
            _buildHelpItem(context, 'Churn Rate',
                'Percentage of customers who have become inactive'),
            _buildHelpItem(context, 'New Customers',
                'Customers who joined during the selected time period'),
            _buildHelpItem(context, 'Lost Customers',
                'Customers who became inactive during the selected time period'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(
      BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: '$title: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                children: [
                  TextSpan(
                    text: description,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeIndicator(BuildContext context) {
    final formattedStart = DateFormat('MMM d, y').format(_selectedRange!.start);
    final formattedEnd = DateFormat('MMM d, y').format(_selectedRange!.end);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Period: $formattedStart to $formattedEnd',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => _selectDateRange(context),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsSummary(
      BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final retentionRate = data['retentionRate'];
    final churnRate = data['churnRate'];

    // Determine if retention is healthy
    final retentionStatus = retentionRate >= 80
        ? 'Healthy'
        : retentionRate >= 60
            ? 'Moderate'
            : 'Critical';

    // Pick color based on status
    final statusColor = retentionRate >= 80
        ? Colors.green
        : retentionRate >= 60
            ? Colors.orange
            : Colors.red;

    return Semantics(
      label:
          'Retention summary: $retentionStatus with ${retentionRate.toStringAsFixed(1)}% retention rate',
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: statusColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retention Status',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        retentionStatus,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      retentionRate >= 80
                          ? Icons.thumb_up
                          : retentionRate >= 60
                              ? Icons.thumbs_up_down
                              : Icons.thumb_down,
                      color: statusColor,
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildProgressStatistic(
                    context,
                    'Keeping',
                    retentionRate,
                    Colors.green,
                    '%',
                  ),
                  const SizedBox(width: 16),
                  _buildProgressStatistic(
                    context,
                    'Losing',
                    churnRate,
                    Colors.red,
                    '%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStatistic(
    BuildContext context,
    String label,
    double value,
    Color color,
    String unit,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.grey[300],
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label:
                'Retention rate card showing ${data['retentionRate'].toStringAsFixed(1)} percent',
            child: Card(
              key: _retentionCardKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Retention Rate',
                          style: theme.textTheme.titleMedium,
                        ),
                        Tooltip(
                          message: 'Percentage of customers retained',
                          child: const Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child:
                          _buildRetentionGauge(context, data['retentionRate']),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${data['retentionRate'].toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getRetentionColor(data['retentionRate']),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Retention Goal: 80%',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Semantics(
            label:
                'Churn rate card showing ${data['churnRate'].toStringAsFixed(1)} percent',
            child: Card(
              key: _churnCardKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Churn Rate',
                          style: theme.textTheme.titleMedium,
                        ),
                        Tooltip(
                          message: 'Percentage of customers lost',
                          child: const Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _buildChurnChart(context, data['churnRate']),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${data['churnRate'].toStringAsFixed(1)}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getChurnColor(data['churnRate']),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target: Under 20%',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetentionGauge(BuildContext context, double retentionRate) {
    // This is a simplified gauge visualization
    final color = _getRetentionColor(retentionRate);
    return SizedBox(
      height: 120,
      width: 120,
      child: Stack(
        children: [
          Center(
            child: SizedBox(
              height: 120,
              width: 120,
              child: CircularProgressIndicator(
                value: retentionRate / 100,
                strokeWidth: 12,
                backgroundColor: Colors.grey[300],
                color: color,
              ),
            ),
          ),
          Center(
            child: Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getRetentionIcon(retentionRate),
                  color: color,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChurnChart(BuildContext context, double churnRate) {
    final color = _getChurnColor(churnRate);

    // Using PieChart to illustrate churn
    return SizedBox(
      height: 120,
      width: 120,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: color,
                  value: churnRate,
                  title: '',
                  radius: 20,
                ),
                PieChartSectionData(
                  color: Colors.grey[300],
                  value: 100 - churnRate,
                  title: '',
                  radius: 20,
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _getChurnIcon(churnRate),
                  color: color,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerActivitySection(
      BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    return Card(
      key: _customersCardKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Activity',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActivityMetric(
                    context,
                    'New Customers',
                    data['newCustomersLast30Days'],
                    Icons.person_add,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildActivityMetric(
                    context,
                    'Lost Customers',
                    data['lostCustomersLast30Days'],
                    Icons.person_remove,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActivityMetric(
                    context,
                    'Active Customers',
                    data['activeCount'],
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildActivityMetric(
                    context,
                    'Inactive Customers',
                    data['inactiveCount'],
                    Icons.people_outline,
                    Colors.grey,
                  ),
                ),
              ],
            ),

            // Net change calculation
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildNetChangeIndicator(
                context,
                data['newCustomersLast30Days'] -
                    data['lostCustomersLast30Days']),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityMetric(
    BuildContext context,
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNetChangeIndicator(BuildContext context, int netChange) {
    final isPositive = netChange > 0;
    final color =
        isPositive ? Colors.green : (netChange < 0 ? Colors.red : Colors.grey);
    final icon = isPositive
        ? Icons.trending_up
        : (netChange < 0 ? Icons.trending_down : Icons.trending_flat);
    final text =
        isPositive ? 'Growing' : (netChange < 0 ? 'Shrinking' : 'Stable');

    return Semantics(
      label:
          'Net customer change: ${netChange.abs()} customers ${isPositive ? 'gained' : (netChange < 0 ? 'lost' : 'unchanged')}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Net Change: ${netChange > 0 ? '+' : ''}$netChange',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($text)',
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(BuildContext context) {
    return Card(
      key: _actionsCardKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  'View Active',
                  Icons.people,
                  Colors.green,
                  () => Navigator.pushNamed(context, '/customers'),
                ),
                _buildActionButton(
                  context,
                  'View Inactive',
                  Icons.people_outline,
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/inactive-customers'),
                ),
                _buildActionButton(
                  context,
                  'Expiring Soon',
                  Icons.timer_outlined,
                  Colors.red,
                  () => Navigator.pushNamed(context, '/expiring-subscriptions'),
                ),
                _buildActionButton(
                  context,
                  'Export Data',
                  Icons.download,
                  Colors.blue,
                  () => _showExportOptions(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // Utility methods
  Color _getRetentionColor(double retentionRate) {
    if (retentionRate >= 80) return Colors.green;
    if (retentionRate >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getChurnColor(double churnRate) {
    if (churnRate <= 20) return Colors.green;
    if (churnRate <= 40) return Colors.orange;
    return Colors.red;
  }

  IconData _getRetentionIcon(double retentionRate) {
    if (retentionRate >= 80) return Icons.sentiment_very_satisfied;
    if (retentionRate >= 60) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  IconData _getChurnIcon(double churnRate) {
    if (churnRate <= 20) return Icons.sentiment_very_satisfied;
    if (churnRate <= 40) return Icons.sentiment_neutral;
    return Icons.sentiment_very_dissatisfied;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedRange = picked;
      });
      // In a real implementation, we would refresh the data with the new date range
      ref.refresh(retentionProvider);
    }
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Export as CSV'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV export started'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Export as PDF Report'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PDF export started'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Summary'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preparing to share summary'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
