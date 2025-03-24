import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:truthy_wifi_manager/database/models/customer.dart';
import 'package:truthy_wifi_manager/database/models/sync_status.dart';
import '../providers/customer_provider.dart';
import '../providers/database_provider.dart';
import '../providers/notification_schedule_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/syncing_provider.dart';

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

      try {
        // Get all active customers first
        final activeCustomers =
            await isar.customers.filter().isActiveEqualTo(true).findAll();

        // Process all updates in a single transaction
        await isar.writeTxn(() async {
          for (final customer in activeCustomers) {
            // Use copyWith to create updated customer
            final updatedCustomer = customer.copyWith(
              subscriptionEnd: customer.subscriptionEnd.add(_downtimeDuration),
            );

            await isar.customers.put(updatedCustomer);
            await isar.syncStatus.put(
              SyncStatus(
                entityId: updatedCustomer.id,
                entityType: 'customer',
                operation: 'save',
                timestamp: DateTime.now(),
              ),
            );

            // Explicitly push to cloud
            await database.pushCustomer(updatedCustomer);
          }
        });

        // Create and schedule actual notifications to customers
        for (final customer in activeCustomers) {
          final message =
              'Your subscription has been extended by ${_downtimeDuration.inHours} hours due to downtime.';
          // Implement actual notification sending here
          // ...
        }

        // Invalidate providers to refresh UI
        ref.invalidate(activeCustomersProvider);
        ref.invalidate(expiringCustomersProvider);
        ref.invalidate(syncingProvider);
        ref.invalidate(databaseProvider);
        ref.invalidate(customerProvider);
        ref.invalidate(expiringSubscriptionsProvider);
        ref.invalidate(notificationSchedulerProvider);

        // Force sync to cloud
        database.syncPendingChanges();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downtime applied successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e, stackTrace) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText(
                'Error applying downtime: $e\n$stackTrace',
              ),
              duration: Duration(seconds: 10),
            ),
          );
        }
      }
    }
  }
}
