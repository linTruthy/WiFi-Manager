// services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models/payment.dart';
import '../providers/customer_provider.dart';
import '../services/receipt_service.dart';

class ReceiptButton extends ConsumerWidget {
  final Payment payment;

  const ReceiptButton({super.key, required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.receipt_long),
      onPressed: () async {
        try {
          final customerAsync = await ref.read(
            customerProvider(payment.customerId).future,
          );
          if (customerAsync != null) {
            await ReceiptService.generateAndShareReceipt(
              payment: payment,
              customer: customerAsync,
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error generating receipt: $e')),
            );
          }
        }
      },
    );
  }
}
