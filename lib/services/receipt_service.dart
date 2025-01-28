// services/notification_service.dart

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/models/customer.dart';
import '../database/models/payment.dart';

class ReceiptService {
  static Future<void> generateAndShareReceipt({
    required Payment payment,
    required Customer customer,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Payment Receipt',
                    style: pw.TextStyle(
                      fontSize: 24,
                      font: pw.Font.helveticaBold(),
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Receipt #: ${payment.id}'),
                pw.Text(
                  'Date: ${DateFormat('MMM d, y').format(payment.paymentDate)}',
                ),
                pw.SizedBox(height: 20),
                pw.Text('Customer Details:'),
                pw.Text('Name: ${customer.name}'),
                pw.Text('Contact: ${customer.contact}'),
                pw.SizedBox(height: 20),
                pw.Text('Payment Details:'),
                pw.Text('Plan: ${payment.planType.name}'),
                pw.Text('Amount: \$${payment.amount.toStringAsFixed(2)}'),
                pw.Text(
                  'Status: ${payment.isConfirmed ? "Confirmed" : "Pending"}',
                ),
                pw.SizedBox(height: 40),
                pw.Text('Thank you for your business!'),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Valid until: ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}',
                ),
              ],
            ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${payment.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Payment Receipt for ${customer.name}');
  }
}
