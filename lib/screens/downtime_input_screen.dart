import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:truthy_wifi_manager/database/models/customer.dart';
import 'package:truthy_wifi_manager/database/models/sync_status.dart';
import '../providers/database_provider.dart';
import '../services/subscription_notification_service.dart';

class DowntimeInputScreen extends ConsumerStatefulWidget {
  const DowntimeInputScreen({super.key});

  @override
  ConsumerState<DowntimeInputScreen> createState() =>
      _DowntimeInputScreenState();
}

class _DowntimeInputScreenState extends ConsumerState<DowntimeInputScreen> {
  final _formKey = GlobalKey<FormState>();
  Duration _downtimeDuration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Downtime')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Downtime Duration (in hours)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a duration';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) {
                  _downtimeDuration = Duration(hours: int.parse(value!));
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _applyDowntime,
                child: const Text('Apply Downtime'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyDowntime() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final database = ref.read(databaseProvider);
      final isar = await database.db;

      // Get all active customers
      final activeCustomers =
          await isar.customers.filter().isActiveEqualTo(true).findAll();

      // Extend subscription end date for each active customer
      for (final customer in activeCustomers) {
        customer.subscriptionEnd = customer.subscriptionEnd.add(
          _downtimeDuration,
        );
        await isar.writeTxn(() async {
          await isar.customers.put(customer);
          await isar.syncStatus.put(
            SyncStatus(
              entityId: customer.id,
              entityType: 'customer',
              operation: 'save',
              timestamp: DateTime.now(),
            ),
          );
        });

        // Notify customer about the extension
        final message =
            'Your subscription has been extended by ${_downtimeDuration.inHours} hours due to downtime.';
        await SubscriptionNotificationService.scheduleExpirationNotification(
          customer,
        );
        // Print the message (for debugging purposes)
        print('Notification sent to ${customer.name}: $message');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downtime applied successfully')),
        );
        Navigator.pop(context);
      }
    }
  }
}
