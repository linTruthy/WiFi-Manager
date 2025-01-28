import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/models/customer.dart';
import '../providers/database_provider.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(activeCustomersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Customers'),
      ),
      body: customersAsync.when(
        data: (customers) => ListView.builder(
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            return CustomerListTile(customer: customer);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class CustomerListTile extends ConsumerWidget {
  final Customer customer;

  const CustomerListTile({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(customer.name),
      subtitle: Text(
        'Expires: ${DateFormat('MMM dd, yyyy').format(customer.subscriptionEnd)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => Navigator.pushNamed(
          context,
          '/edit-customer',
          arguments: customer,
        ),
      ),
    );
  }
}
