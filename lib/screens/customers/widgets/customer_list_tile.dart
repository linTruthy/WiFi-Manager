import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthy_wifi_manager/database/models/customer.dart';

class CustomerListTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerListTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Expires: ${DateFormat('MMM dd, yyyy - hh:mm a').format(customer.subscriptionEnd)}',
              style: TextStyle(
                color:
                    customer.subscriptionEnd.difference(DateTime.now()).inDays <
                            3
                        ? Colors.red
                        : null,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed:
              () => Navigator.pushNamed(
                context,
                '/edit-customer/${customer.id}',
                arguments: customer,
              ),
        ),
      ),
    );
  }
}
