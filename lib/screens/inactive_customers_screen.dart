import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/models/customer.dart';
import '../providers/customer_provider.dart';
import '../providers/database_provider.dart';
import '../services/subscription_notification_service.dart';
import '../widgets/add_payment_dialog.dart'; // Import AddPaymentDialog

class InactiveCustomersScreen extends ConsumerWidget {
  const InactiveCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inactiveCustomersAsync = ref.watch(inactiveCustomersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inactive Customers')),
      body: inactiveCustomersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No inactive customers found.'));
          }
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _InactiveCustomerTile(
                customer: customer,
                onDelete: (deleteAssociatedData) async {
                  final database = ref.read(databaseProvider);
                  await database.deleteCustomerWithData(
                    customer.id,
                    deleteAssociatedData,
                  );
                  ref.invalidate(inactiveCustomersProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Customer deleted successfully'),
                    ),
                  );
                },
                onActivate: () async {
                  await _activateCustomer(context, ref, customer);
                },
                onAddPaymentAndActivate: () async {
                  await _addPaymentAndActivate(context, ref, customer);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _activateCustomer(
      BuildContext context, WidgetRef ref, Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Customer'),
        content: Text('Are you sure you want to activate ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final database = ref.read(databaseProvider);
      await database.activateCustomer(customer.id);
      ref.invalidate(inactiveCustomersProvider);
      ref.invalidate(activeCustomersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} has been activated')),
      );
      final message =
          'Your subscription has been reactivated. Thank you for choosing our services!';
      await SubscriptionNotificationService.scheduleExpirationNotification(
          customer);
      print('Notification sent to ${customer.name}: $message');
    }
  }

  Future<void> _addPaymentAndActivate(
      BuildContext context, WidgetRef ref, Customer customer) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddPaymentDialog(customer: customer),
    );
    if (result == true) {
      final database = ref.read(databaseProvider);
      await database.activateCustomer(customer.id);
      ref.invalidate(inactiveCustomersProvider);
      ref.invalidate(activeCustomersProvider);
      ref.invalidate(recentPaymentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.name} has been activated and payment added')),
      );
      final message =
          'Your subscription has been reactivated with a new payment. Thank you!';
      await SubscriptionNotificationService.scheduleExpirationNotification(
          customer);
      print('Notification sent to ${customer.name}: $message');
    }
  }
}

class _InactiveCustomerTile extends StatelessWidget {
  final Customer customer;
  final Function(bool) onDelete;
  final VoidCallback onActivate;
  final VoidCallback onAddPaymentAndActivate;

  const _InactiveCustomerTile({
    required this.customer,
    required this.onDelete,
    required this.onActivate,
    required this.onAddPaymentAndActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(customer.name),
        subtitle: Text(
          'Expired: ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}',
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'activate',
              child: Text('Activate Customer'),
            ),
            const PopupMenuItem(
              value: 'add_payment_and_activate',
              child: Text('Add Payment & Activate'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Customer'),
            ),
            const PopupMenuItem(
              value: 'delete_with_data',
              child: Text('Delete Customer with All Data'),
            ),
          ],
          onSelected: (value) {
            if (value == 'activate') {
              onActivate();
            } else if (value == 'add_payment_and_activate') {
              onAddPaymentAndActivate();
            } else if (value == 'delete') {
              onDelete(false);
            } else if (value == 'delete_with_data') {
              onDelete(true);
            }
          },
        ),
      ),
    );
  }
}