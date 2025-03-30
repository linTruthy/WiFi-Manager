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
  // Price settings
  late double _dailyPrice;
  late double _weeklyPrice;
  late double _monthlyPrice;

  // Notification settings
  late Map<String, dynamic> _notificationSettings;
  bool _enableNotifications = false;

  // App update states
  AppUpdateInfo? _updateInfo;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _flexibleUpdateAvailable = false;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  // Controllers for text editing
  final TextEditingController _dailyPriceController = TextEditingController();
  final TextEditingController _weeklyPriceController = TextEditingController();
  final TextEditingController _monthlyPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNotifications();

    // Initialize text controllers with default values
    _dailyPriceController.text = '2000.0';
    _weeklyPriceController.text = '10000.0';
    _monthlyPriceController.text = '35000.0';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dailyPriceController.dispose();
    _weeklyPriceController.dispose();
    _monthlyPriceController.dispose();
    super.dispose();
  }

  // Check for app updates
  Future<void> _checkForUpdate() async {
    setState(() => _isLoading = true);
    try {
      final info = await InAppUpdate.checkForUpdate();
      setState(() {
        _updateInfo = info;
        _isLoading = false;
      });
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _showUpdateDialog();
      } else {
        _showSnackBar('Your app is up to date!');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error checking for update: $e');
    }
  }

  // Display a snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade800 : null,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  // Show update dialog
  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update_outlined, size: 40),
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
              child: const Text('Update in Background'),
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

  // Perform immediate app update
  Future<void> _performImmediateUpdate() async {
    setState(() => _isLoading = true);
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      setState(() => _isLoading = false);
      if (result == AppUpdateResult.inAppUpdateFailed) {
        _showSnackBar('Update failed. Please try again later.', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error during update: $e', isError: true);
    }
  }

  // Start flexible app update
  Future<void> _startFlexibleUpdate() async {
    setState(() => _isLoading = true);
    try {
      await InAppUpdate.startFlexibleUpdate();
      setState(() {
        _flexibleUpdateAvailable = true;
        _isLoading = false;
      });
      _showSnackBar('Update downloaded. Complete it when ready.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error starting update: $e', isError: true);
    }
  }

  // Complete flexible app update
  Future<void> _completeFlexibleUpdate() async {
    setState(() => _isLoading = true);
    try {
      await InAppUpdate.completeFlexibleUpdate();
      _showSnackBar('Update completed successfully!');
      setState(() {
        _flexibleUpdateAvailable = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error completing update: $e', isError: true);
    }
  }

  // Check notification permissions
  Future<void> _checkNotifications() async {
    if (Platform.isAndroid) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      setState(() {
        _enableNotifications = alarmStatus.isGranted;
      });

      if (_enableNotifications) {
        await SubscriptionNotificationService.initialize();
      }
    }
  }

  // Request exact alarm permissions (Android)
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: Uri.parse('package:com.truthysystems.wifi').toString(),
      );
      await intent.launch();

      // Add a delay and recheck permission
      await Future.delayed(const Duration(seconds: 2));
      _checkNotifications();
    }
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      await SubscriptionNotificationService.loadSettings();
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _notificationSettings =
            Map.from(SubscriptionNotificationService.reminderSettings);
        _dailyPrice = prefs.getDouble('dailyPrice') ?? 2000.0;
        _weeklyPrice = prefs.getDouble('weeklyPrice') ?? 10000.0;
        _monthlyPrice = prefs.getDouble('monthlyPrice') ?? 35000.0;

        _dailyPriceController.text = _dailyPrice.toStringAsFixed(0);
        _weeklyPriceController.text = _weeklyPrice.toStringAsFixed(0);
        _monthlyPriceController.text = _monthlyPrice.toStringAsFixed(0);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  // Save settings
  Future<void> _saveSettings() async {
    if (!_validateSettings()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Update notification settings
      await SubscriptionNotificationService.saveSettings(_notificationSettings);

      // Update plan prices
      final database = ref.read(databaseProvider);
      await _updatePlanPrices(database);

      // Schedule notifications
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
        _showSnackBar('Settings saved successfully!');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: $e';
      });
      if (mounted) {
        _showSnackBar('Failed to save settings: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Validate settings before saving
  bool _validateSettings() {
    bool isValid = true;
    String? errorMessage;

    // Validate daily price
    try {
      final daily = double.parse(_dailyPriceController.text);
      if (daily <= 0) {
        errorMessage = 'Daily price must be greater than zero';
        isValid = false;
      } else {
        _dailyPrice = daily;
      }
    } catch (e) {
      errorMessage = 'Invalid daily price format';
      isValid = false;
    }

    // Validate weekly price
    try {
      final weekly = double.parse(_weeklyPriceController.text);
      if (weekly <= 0) {
        errorMessage = 'Weekly price must be greater than zero';
        isValid = false;
      } else {
        _weeklyPrice = weekly;
      }
    } catch (e) {
      errorMessage = 'Invalid weekly price format';
      isValid = false;
    }

    // Validate monthly price
    try {
      final monthly = double.parse(_monthlyPriceController.text);
      if (monthly <= 0) {
        errorMessage = 'Monthly price must be greater than zero';
        isValid = false;
      } else {
        _monthlyPrice = monthly;
      }
    } catch (e) {
      errorMessage = 'Invalid monthly price format';
      isValid = false;
    }

    if (!isValid && errorMessage != null) {
      setState(() {
        _errorMessage = errorMessage;
      });
      _showSnackBar(errorMessage, isError: true);
    }

    return isValid;
  }

  // Update plan prices in database
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

    // Also update shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dailyPrice', _dailyPrice);
    await prefs.setDouble('weeklyPrice', _weeklyPrice);
    await prefs.setDouble('monthlyPrice', _monthlyPrice);
  }

  // Reset all settings to defaults with confirmation
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _dailyPrice = 2000.0;
        _weeklyPrice = 10000.0;
        _monthlyPrice = 35000.0;

        _dailyPriceController.text = '2000.0';
        _weeklyPriceController.text = '10000.0';
        _monthlyPriceController.text = '35000.0';

        _notificationSettings = {
          'daysBeforeDaily': 0,
          'daysBeforeWeekly': 1,
          'daysBeforeMonthly': 3,
        };
      });

      _showSnackBar('Settings reset to defaults');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null && _errorMessage!.isNotEmpty
              ? _buildErrorState()
              : _buildSettingsContent(),
    );
  }

  // Loading state UI
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading settings...'),
        ],
      ),
    );
  }

  // Error state UI
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
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Main settings content
  Widget _buildSettingsContent() {
    return RefreshIndicator(
      onRefresh: _loadSettings,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            // Status indicator
            if (_errorMessage != null && _errorMessage!.isNotEmpty)
              _buildErrorBanner(),

            // Notification settings
            _buildSectionHeader(
                'Notification Settings', Icons.notifications_outlined),
            _buildNotificationSettings(),
            const SizedBox(height: 24),

            // Pricing settings
            _buildSectionHeader('Package Prices', Icons.attach_money),
            _buildPriceSettings(),
            const SizedBox(height: 24),

            // App settings
            _buildSectionHeader('App Settings', Icons.settings_outlined),
            _buildAppSettings(),
            const SizedBox(height: 24),

            // Updates section
            if (Platform.isAndroid) ...[
              _buildSectionHeader('App Updates', Icons.system_update_outlined),
              _buildUpdatesSection(),
              const SizedBox(height: 24),
            ],

            // Actions section
            _buildSectionHeader('Actions', Icons.save_outlined),
            _buildActionButtons(),
            const SizedBox(height: 36),

            // About section
            _buildAboutSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Error banner display
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[300]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[300]),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red[300]),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  // Section header with icon
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            semanticsLabel: title,
          ),
        ],
      ),
    );
  }

  // Notification settings card
  Widget _buildNotificationSettings() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable notifications toggle
            Semantics(
              label: 'Enable notifications',
              hint:
                  'Toggle to enable or disable all subscription notifications',
              child: SwitchListTile(
                title: const Text('Enable notifications'),
                subtitle: const Text('Get alerts before subscriptions expire'),
                value: _enableNotifications,
                onChanged: (value) {
                  setState(() {
                    _enableNotifications = value;
                  });
                  if (_enableNotifications) {
                    _checkNotifications();
                  } else {
                    requestExactAlarmPermission();
                  }
                },
                secondary: Icon(
                  _enableNotifications
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _enableNotifications
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ),

            if (_enableNotifications) ...[
              const Divider(height: 24),
              const Text(
                'Notification Timing',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how many days before expiration to send notifications',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Daily plan notification slider
              _buildReminderSlider(
                'Daily Plan',
                'daysBeforeDaily',
                Icons.calendar_today,
              ),

              // Weekly plan notification slider
              _buildReminderSlider(
                'Weekly Plan',
                'daysBeforeWeekly',
                Icons.calendar_view_week,
              ),

              // Monthly plan notification slider
              _buildReminderSlider(
                'Monthly Plan',
                'daysBeforeMonthly',
                Icons.calendar_month,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Notification reminder slider
  Widget _buildReminderSlider(String label, String key, IconData icon) {
    return Semantics(
      label: '$label notification reminder setting',
      value: 'Notify ${_notificationSettings[key]} days before expiration',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 15))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_notificationSettings[key]} ${_notificationSettings[key] == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                trackShape: const RoundedRectSliderTrackShape(),
                trackHeight: 4.0,
                thumbColor: Theme.of(context).colorScheme.primary,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                overlayColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 20.0),
              ),
              child: Slider(
                value: _notificationSettings[key].toDouble(),
                min: 0,
                max: 7,
                divisions: 7,
                onChanged: (value) {
                  setState(() {
                    _notificationSettings[key] = value.round();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Price settings card
  Widget _buildPriceSettings() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set default prices for each subscription plan',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Daily price input
            _buildPriceInput(
              'Daily Price',
              _dailyPriceController,
              Icons.calendar_today,
              500.0,
              5000.0,
              (value) {
                if (value.isNotEmpty) {
                  _dailyPrice = double.tryParse(value) ?? _dailyPrice;
                }
              },
            ),

            // Weekly price input
            _buildPriceInput(
              'Weekly Price',
              _weeklyPriceController,
              Icons.calendar_view_week,
              2000.0,
              20000.0,
              (value) {
                if (value.isNotEmpty) {
                  _weeklyPrice = double.tryParse(value) ?? _weeklyPrice;
                }
              },
            ),

            // Monthly price input
            _buildPriceInput(
              'Monthly Price',
              _monthlyPriceController,
              Icons.calendar_month,
              5000.0,
              50000.0,
              (value) {
                if (value.isNotEmpty) {
                  _monthlyPrice = double.tryParse(value) ?? _monthlyPrice;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Price input field
  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
    IconData icon,
    double min,
    double max,
    Function(String) onChanged,
  ) {
    return Semantics(
      label: '$label setting',
      value: 'Current value: UGX ${controller.text}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: label,
                  prefixText: 'UGX ',
                  helperText:
                      'Range: UGX ${min.toStringAsFixed(0)} - ${max.toStringAsFixed(0)}',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // App settings section
  Widget _buildAppSettings() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Theme setting
          Semantics(
            label: 'App theme setting',
            child: ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('App Theme'),
              subtitle: const Text('Dark theme is currently applied'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showSnackBar(
                    'Theme settings will be available in the next update');
              },
            ),
          ),
          const Divider(height: 1),

          // Language setting
          Semantics(
            label: 'App language setting',
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showSnackBar(
                    'Language settings will be available in the next update');
              },
            ),
          ),
          const Divider(height: 1),

          // Data backup setting
          Semantics(
            label: 'Data backup setting',
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Data Backup'),
              subtitle: const Text('Manage your data backups'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showSnackBar(
                    'Backup features will be available in the next update');
              },
            ),
          ),
        ],
      ),
    );
  }

  // Updates section for Android
  Widget _buildUpdatesSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _updateInfo?.updateAvailability ==
                            UpdateAvailability.updateAvailable
                        ? 'Update available!'
                        : 'App is up to date',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Check for update button
            Semantics(
              label: 'Check for update button',
              button: true,
              enabled: !_isLoading,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkForUpdate,
                icon: _isLoading
                    ? Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(2),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Check for Update'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Update options if available
            if (_updateInfo?.updateAvailability ==
                UpdateAvailability.updateAvailable) ...[
              const SizedBox(height: 12),

              // Immediate update button
              if (_updateInfo?.immediateUpdateAllowed == true)
                Semantics(
                  label: 'Perform immediate update button',
                  button: true,
                  enabled: !_isLoading,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _performImmediateUpdate,
                    icon: const Icon(Icons.system_update),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

              // Flexible update button
              if (_updateInfo?.flexibleUpdateAllowed == true &&
                  !_flexibleUpdateAvailable) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: 'Start flexible update button',
                  button: true,
                  enabled: !_isLoading,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _startFlexibleUpdate,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Update'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],

              // Complete update button
              if (_flexibleUpdateAvailable) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: 'Complete flexible update button',
                  button: true,
                  enabled: !_isLoading,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _completeFlexibleUpdate,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Install Update'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Action buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Save button
        Expanded(
          flex: 2,
          child: Semantics(
            label: 'Save settings button',
            button: true,
            enabled: !_isSaving,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(2),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Reset button
        Expanded(
          child: Semantics(
            label: 'Reset settings to defaults',
            button: true,
            enabled: !_isSaving,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetToDefaults,
              icon: const Icon(Icons.restore),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // About section
  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // About
          Semantics(
            label: 'About Truthy Systems',
            enabled: true,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, '/about'),
            ),
          ),
          const Divider(height: 1),

          // How to use
          Semantics(
            label: 'How to use the app',
            enabled: true,
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('How to use'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, '/how-to'),
            ),
          ),
          const Divider(height: 1),

          // Privacy policy
          Semantics(
            label: 'Privacy policy',
            enabled: true,
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, '/privacy'),
            ),
          ),
          const Divider(height: 1),

          // Contact support
          Semantics(
            label: 'Contact support',
            enabled: true,
            child: ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Contact Support'),
              subtitle: const Text('truthysys@proton.me'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showSnackBar('Support contact: truthysys@proton.me');
              },
            ),
          ),
        ],
      ),
    );
  }

  // Help dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Settings Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                'Notification Settings',
                'Control when customers receive reminders about their subscription expiration.',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'Package Prices',
                'Set default prices for each subscription plan type.',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'App Updates',
                'Check for and install the latest version of Truthy WiFi Manager.',
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'Save Settings',
                'Don\'t forget to save your changes by clicking the Save button at the bottom.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  // Help item
  Widget _buildHelpItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
