import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/models/customer.dart';
import '../database/models/plan.dart';
import '../database/repository/database_repository.dart';
import '../providers/database_provider.dart';
import '../services/subscription_notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // late double _daysBeforeDaily;
  // late double _daysBeforeWeekly;
  // late double _daysBeforeMonthly;
  // late bool _priorityUrgent;
  // late bool _enableSnooze;
  late double _dailyPrice;
  late double _weeklyPrice;
  late double _monthlyPrice;
  bool _isSaving = false;
  late Map<String, dynamic> _notificationSettings;
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SubscriptionNotificationService.loadSettings();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationSettings =
          Map.from(SubscriptionNotificationService.reminderSettings);

      _dailyPrice = prefs.getDouble('dailyPrice') ?? 2000.0;
      _weeklyPrice = prefs.getDouble('weeklyPrice') ?? 10000.0;
      _monthlyPrice = prefs.getDouble('monthlyPrice') ?? 35000.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildNotificationSettingsCard(),
            const SizedBox(height: 16),
            _buildPriceSettingsCard(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 24),
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => Navigator.pushNamed(context, '/about'),
            ),
            IconButton(
              icon: const Icon(Icons.help),
              onPressed: () => Navigator.pushNamed(context, '/how-to'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildSlider('Daily Plan (days before)', 'daysBeforeDaily'),
            _buildSlider('Weekly Plan (days before)', 'daysBeforeWeekly'),
            _buildSlider('Monthly Plan (days before)', 'daysBeforeMonthly'),
            //   const Divider(height: 24),
            // CheckboxListTile(
            //   title: const Text(
            //       'Prioritize urgent notifications (expiring today)'),
            //   value: _priorityUrgent,
            //   onChanged: (value) =>
            //       setState(() => _priorityUrgent = value ?? true),
            // ),
            // CheckboxListTile(
            //   title: const Text('Enable snooze option'),
            //   value: _enableSnooze,
            //   onChanged: (value) =>
            //       setState(() => _enableSnooze = value ?? true),
            // ),
          ],
        ),
      ),
    );
  }

  /// Build a slider widget for adjusting days
  Widget _buildSlider(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        Slider(
          value: _notificationSettings[key].toDouble(),
          min: 0,
          max: 7,
          divisions: 7,
          label: _notificationSettings[key].toString(),
          onChanged: (value) {
            setState(() {
              _notificationSettings[key] = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriceSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Package Prices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildPriceSlider('Daily Price', _dailyPrice, 500.0, 5000.0,
                (value) {
              setState(() => _dailyPrice = value);
            }),
            _buildPriceSlider('Weekly Price', _weeklyPrice, 2000.0, 20000.0,
                (value) {
              setState(() => _weeklyPrice = value);
            }),
            _buildPriceSlider('Monthly Price', _monthlyPrice, 5000.0, 50000.0,
                (value) {
              setState(() => _monthlyPrice = value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderWithLabel({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)} $unit'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(1)} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPriceSlider(String label, double value, double min, double max,
      Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: UGX ${value.toStringAsFixed(0)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 500).round(),
          label: 'UGX ${value.toStringAsFixed(0)}',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveSettings,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      child: _isSaving
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Save Settings', style: TextStyle(fontSize: 16)),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await SubscriptionNotificationService.saveSettings(_notificationSettings);

      final database = ref.read(databaseProvider);
      await _updatePlanPrices(database);
      final snapshot = await database.firestore
          .collection(database.getUserCollectionPath('customers'))
          .where('isActive', isEqualTo: true)
          .get();
      final customers = snapshot.docs
          .map((doc) => Customer.fromJson(doc.id, doc.data()))
          .toList();

      await SubscriptionNotificationService.scheduleExpirationNotifications(
          customers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updatePlanPrices(DatabaseRepository database) async {
    final plans = [
      Plan(type: PlanType.daily, price: _dailyPrice, durationInDays: 1),
      Plan(type: PlanType.weekly, price: _weeklyPrice, durationInDays: 7),
      Plan(type: PlanType.monthly, price: _monthlyPrice, durationInDays: 30),
    ];

    final batch = database.firestore.batch();
    for (var plan in plans) {
      final ref = database.firestore.collection('plans').doc(plan.type.name);
      batch.set(ref, plan.toJson());
    }
    await batch.commit();
  }
}
