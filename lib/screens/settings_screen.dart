import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/models/customer.dart';
import '../providers/database_provider.dart';
import '../services/subscription_notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late double _daysBeforeDaily;
  late double _daysBeforeWeekly;
  late double _daysBeforeMonthly;
  late bool _priorityUrgent;
  late bool _enableSnooze;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SubscriptionNotificationService.loadSettings();
    setState(() {
      _daysBeforeDaily = SubscriptionNotificationService
          .reminderSettings['daysBeforeDaily'] as double;
      _daysBeforeWeekly = SubscriptionNotificationService
          .reminderSettings['daysBeforeWeekly'] as double;
      _daysBeforeMonthly = SubscriptionNotificationService
          .reminderSettings['daysBeforeMonthly'] as double;
      _priorityUrgent = SubscriptionNotificationService
          .reminderSettings['priorityUrgent'] as bool;
      _enableSnooze = SubscriptionNotificationService
          .reminderSettings['enableSnooze'] as bool;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Slider(
              value: _daysBeforeDaily,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${_daysBeforeDaily.toStringAsFixed(1)} hours',
              onChanged: (value) => setState(() => _daysBeforeDaily = value),
            ),
            Text(
                'Notify ${(_daysBeforeDaily * 24).toStringAsFixed(1)} hours before daily expiration'),
            Slider(
              value: _daysBeforeWeekly,
              min: 0.5,
              max: 2.0,
              divisions: 8,
              label: '${_daysBeforeWeekly.toStringAsFixed(1)} days',
              onChanged: (value) => setState(() => _daysBeforeWeekly = value),
            ),
            Text(
                'Notify ${_daysBeforeWeekly.toStringAsFixed(1)} days before weekly expiration'),
            Slider(
              value: _daysBeforeMonthly,
              min: 1.0,
              max: 7.0,
              divisions: 12,
              label: '${_daysBeforeMonthly.toStringAsFixed(1)} days',
              onChanged: (value) => setState(() => _daysBeforeMonthly = value),
            ),
            Text(
                'Notify ${_daysBeforeMonthly.toStringAsFixed(1)} days before monthly expiration'),
            CheckboxListTile(
              title: const Text(
                  'Prioritize urgent notifications (expiring today)'),
              value: _priorityUrgent,
              onChanged: (value) =>
                  setState(() => _priorityUrgent = value ?? true),
            ),
            CheckboxListTile(
              title: const Text('Enable snooze option'),
              value: _enableSnooze,
              onChanged: (value) =>
                  setState(() => _enableSnooze = value ?? true),
            ),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      await SubscriptionNotificationService.saveSettings({
        'daysBeforeDaily': _daysBeforeDaily,
        'daysBeforeWeekly': _daysBeforeWeekly,
        'daysBeforeMonthly': _daysBeforeMonthly,
        'priorityUrgent': _priorityUrgent,
        'enableSnooze': _enableSnooze,
      });

      final database = ref.read(databaseProvider);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save settings: $e')));
      }
    }
  }
}
