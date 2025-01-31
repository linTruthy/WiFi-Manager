import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wifi_manager/providers/customer_provider.dart';
import 'package:wifi_manager/providers/database_provider.dart';

import '../database/models/customer.dart';

class InactiveCustomersScreen extends ConsumerWidget {
  const InactiveCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inactiveCustomersAsync = ref.watch(inactiveCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inactive Customers'),
      ),
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
                    const SnackBar(content: Text('Customer deleted successfully')),
                  );
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
}

class _InactiveCustomerTile extends StatelessWidget {
  final Customer customer;
  final Function(bool) onDelete;

  const _InactiveCustomerTile({
    required this.customer,
    required this.onDelete,
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
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
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
            if (value == 'delete') {
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