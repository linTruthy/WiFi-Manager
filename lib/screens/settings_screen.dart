import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _enableNotifications = false;
  AppUpdateInfo? _updateInfo;
  bool _isLoading = false;
  bool _flexibleUpdateAvailable = false;
  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      setState(() {
        _updateInfo = info;
      });
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _showUpdateDialog();
      }
    } catch (e) {
      _showSnackBar('Error checking for update: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of Truthy WiFi Manager is available. Update now to get the latest features and improvements.',
        ),
        actions: [
          if (_updateInfo?.flexibleUpdateAllowed == true)
            TextButton(
              onPressed: () {
                _startFlexibleUpdate();
                Navigator.pop(context);
              },
              child: const Text('Flexible Update'),
            ),
          if (_updateInfo?.immediateUpdateAllowed == true)
            ElevatedButton(
              onPressed: () {
                _performImmediateUpdate();
                Navigator.pop(context);
              },
              child: const Text('Update Now'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
        ],
      ),
    );
  }

  Future<void> _performImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.inAppUpdateFailed) {
        _showSnackBar('Immediate update failed. Please try again.');
      }
    } catch (e) {
      _showSnackBar('Error during immediate update: $e');
    }
  }

  Future<void> _startFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      setState(() {
        _flexibleUpdateAvailable = true;
      });
      _showSnackBar('Flexible update started. Complete it when ready.');
    } catch (e) {
      _showSnackBar('Error starting flexible update: $e');
    }
  }

  Future<void> _completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
      _showSnackBar('Update completed successfully!');
      setState(() {
        _flexibleUpdateAvailable = false;
      });
    } catch (e) {
      _showSnackBar('Error completing flexible update: $e');
    }
  }

  Future<void> _checkNotifications() async {
    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      alarmStatus.isGranted
          ? _enableNotifications = true
          : _enableNotifications = false;
      if (_enableNotifications) {
        await SubscriptionNotificationService.initialize();
      }
      if (!_enableNotifications) {
        await requestExactAlarmPermission();
      }
// Suggested code may be subject to a license. Learn more: ~LicenseLog:1328499430.
      setState(() {});
    }
  }

  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: Uri.parse('package:com.truthysystems.wifi').toString(),
      );
      await intent.launch();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNotifications();
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
            TextButton.icon(
              label: Text('About'),
              icon: const Icon(Icons.info),
              onPressed: () => Navigator.pushNamed(context, '/about'),
            ),
            TextButton.icon(
// Suggested code may be subject to a license. Learn more: ~LicenseLog:3090475375.
              label: Text('How to use'),
              icon: const Icon(Icons.help),
              onPressed: () => Navigator.pushNamed(context, '/how-to'),
            ),
            TextButton.icon(
              label: Text('Privacy Policy'),
              icon: const Icon(Icons.privacy_tip),
              onPressed: () => Navigator.pushNamed(context, '/privacy'),
            ),
            // Update Buttons (Android only)
            if (Platform.isAndroid) ...[
              Semantics(
                label: 'Check for update button',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _checkForUpdate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Check for Update'),
                  ),
                ),
              ),
              if (_updateInfo?.updateAvailability ==
                  UpdateAvailability.updateAvailable)
                Column(
                  children: [
                    if (_updateInfo?.immediateUpdateAllowed == true)
                      Semantics(
                        label: 'Perform immediate update button',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _performImmediateUpdate,
                            child: const Text('Update Now'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_updateInfo?.flexibleUpdateAllowed == true) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Start flexible update button',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startFlexibleUpdate,
                            child: const Text('Start Flexible Update'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_flexibleUpdateAvailable) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Complete flexible update button',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _completeFlexibleUpdate,
                            child: const Text('Complete Flexible Update'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
            ],
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
            const Divider(height: 24),
            //request notification permission
            CheckboxListTile(
              title: const Text('Enable notifications'),
              value: _enableNotifications,
              onChanged: (value) => setState(() {
                _enableNotifications = value ?? true;
                if (_enableNotifications) {
                  _checkNotifications();
                }

                //)
              }),
            ),
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
