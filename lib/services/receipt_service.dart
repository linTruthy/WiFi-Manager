import 'dart:io';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:wifi_manager/database/models/plan.dart';
import '../database/models/customer.dart';
import '../database/models/payment.dart';

class ReceiptService {
  static final _currency = NumberFormat.currency(
    symbol: 'UGX ',
    decimalDigits: 0,
  );

  static Future<void> generateAndShareReceipt({
    required Payment payment,
    required Customer customer,
  }) async {
    final pdf = pw.Document();
    final isar = Isar.getInstance('wifi_manager');
    final referrer =
        customer.referredBy != null
            ? await isar?.customers.get(int.parse(customer.referredBy!))
            : null;
    final titleStyle = pw.TextStyle(
      font: pw.Font.helveticaBold(),
      fontSize: 24,
      color: PdfColors.blue900,
    );
    final headerStyle = pw.TextStyle(
      font: pw.Font.helveticaBold(),
      fontSize: 14,
      color: PdfColors.blue900,
    );
    final subtitleStyle = pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: 12,
      color: PdfColors.grey800,
    );
    final labelStyle = pw.TextStyle(
      font: pw.Font.helveticaBold(),
      fontSize: 10,
      color: PdfColors.grey700,
    );
    final valueStyle = pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: 10,
      color: PdfColors.black,
    );
    final noteStyle = pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: 10,
      color: PdfColors.grey700,
      fontStyle: pw.FontStyle.italic,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TRUTHY SYSTEMS', style: titleStyle),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Internet Service Provider',
                            style: subtitleStyle,
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(4),
                          ),
                        ),
                        child: pw.Text('RECEIPT', style: headerStyle),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    color: PdfColors.grey100,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Receipt No:', style: labelStyle),
                            pw.SizedBox(height: 4),
                            pw.Text('${payment.id}', style: valueStyle),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Date:', style: labelStyle),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              DateFormat(
                                'MMMM d, y',
                              ).format(payment.paymentDate),
                              style: valueStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CUSTOMER DETAILS', style: headerStyle),
                        pw.SizedBox(height: 10),
                        _buildInfoRow(
                          'Customer Name',
                          customer.name,
                          labelStyle,
                          valueStyle,
                        ),
                        _buildInfoRow(
                          'Contact',
                          customer.contact,
                          labelStyle,
                          valueStyle,
                        ),
                        _buildInfoRow(
                          'Subscription Period',
                          '${DateFormat('MMM d, y').format(customer.subscriptionStart)} - ${DateFormat('MMM d, y').format(customer.subscriptionEnd)}',
                          labelStyle,
                          valueStyle,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // Payment Details
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    color: PdfColors.grey100,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT DETAILS', style: headerStyle),
                        pw.SizedBox(height: 10),
                        _buildInfoRow(
                          'Plan Type',
                          payment.planType.name.toUpperCase(),
                          labelStyle,
                          valueStyle,
                        ),
                        _buildInfoRow(
                          'Amount Paid',
                          _currency.format(payment.amount),
                          labelStyle,
                          valueStyle,
                        ),
                        _buildInfoRow(
                          'Payment Status',
                          payment.isConfirmed ? 'Confirmed' : 'Pending',
                          labelStyle,
                          valueStyle,
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 20),
                  // Add referral information
                  if (referrer != null)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(4),
                        ),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('REFERRAL INFORMATION', style: headerStyle),
                          pw.SizedBox(height: 10),
                          _buildInfoRow(
                            'Referred By',
                            referrer.name,
                            labelStyle,
                            valueStyle,
                          ),
                          _buildInfoRow(
                            'Referral Reward',
                            '${_calculateReferralReward(referrer.planType, customer.planType).inDays} days free',
                            labelStyle,
                            valueStyle,
                          ),
                        ],
                      ),
                    ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('YOUR REFERRAL CODE', style: headerStyle),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          customer.referralCode,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Share your referral code with friends and earn free subscription days!',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'For every friend who joins using your referral code, you get:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          '- 7 days free for monthly plan referrals',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.Text(
                          '- 3 days free for weekly plan referrals',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                          ),
                        ),
                        pw.Text(
                          '- 1 day free for daily plan referrals',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  // WiFi Credentials
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue200),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('WIFI CREDENTIALS', style: headerStyle),
                        pw.SizedBox(height: 10),
                        _buildInfoRow(
                          'WiFi Name',
                          customer.wifiName,
                          labelStyle,
                          valueStyle,
                        ),
                        _buildInfoRow(
                          'Password',
                          customer.currentPassword,
                          labelStyle,
                          valueStyle,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Note: Connection is limited to 2 devices at a time with speeds up to 60Mbps',
                          style: noteStyle,
                        ),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 20),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300),
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Thank you for choosing Truthy Systems!',
                          style: headerStyle.copyWith(color: PdfColors.blue700),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'For support, please contact: 0783009649',
                          style: valueStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/truthy_systems_receipt_${payment.id}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Payment Receipt - ${customer.name}',
      subject: 'Truthy Systems - Internet Service Receipt',
    );
  }

  static pw.Row _buildInfoRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  static Duration _calculateReferralReward(
    PlanType referrerPlan,
    PlanType newCustomerPlan,
  ) {
    // Define referral rewards based on plans
    if (newCustomerPlan == PlanType.monthly) {
      return const Duration(days: 7); // 7 days free for monthly plan referral
    } else if (newCustomerPlan == PlanType.weekly) {
      return const Duration(days: 3); // 3 days free for weekly plan referral
    } else {
      return const Duration(days: 1); // 1 day free for daily plan referral
    }
  }
}

