import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../database/models/customer.dart';
import '../database/models/payment.dart';
import '../database/models/plan.dart';

/// A service for generating, previewing, and sharing payment receipts.
class ReceiptService {
  static final _currency = NumberFormat.currency(
    symbol: 'UGX ',
    decimalDigits: 0,
  );

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets the user collection path for the current authenticated user
  static String _getUserCollectionPath(String collection) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return 'users/${user.uid}/$collection';
  }

  /// Generates a receipt PDF for a payment and returns the PDF document
  static Future<pw.Document> generateReceiptDocument({
    required Payment payment,
    required Customer customer,
  }) async {
    // Load fonts for better typography
    final regularFont = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();
    final italicFont = await PdfGoogleFonts.nunitoItalic();

    // Get company information from Firestore (future enhancement)
    Map<String, dynamic> companyInfo = {
      'name': 'Truthy Systems',
      'address': 'Kampala, Uganda',
      'phone': '+256-783-009649',
      'email': 'truthysys@proton.me',
      'website': 'www.truthysystems.com',
      'taxId': 'UG12345678',
    };

    // Try to get the referrer information
    final referrerDoc = customer.referredBy != null
        ? await _firestore
            .collection(_getUserCollectionPath('customers'))
            .doc(customer.referredBy)
            .get()
        : null;

    final referrer = referrerDoc != null && referrerDoc.exists
        ? Customer.fromJson(referrerDoc.id, referrerDoc.data()!)
        : null;

    // Define styles for consistent look
    final titleStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 24,
      color: PdfColors.blue900,
    );

    final headerStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 16,
      color: PdfColors.blue900,
    );

    final subheaderStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 14,
      color: PdfColors.blue700,
    );

    final subtitleStyle = pw.TextStyle(
      font: regularFont,
      fontSize: 12,
      color: PdfColors.grey800,
    );

    final labelStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 10,
      color: PdfColors.grey800,
    );

    final valueStyle = pw.TextStyle(
      font: regularFont,
      fontSize: 10,
      color: PdfColors.black,
    );

    final noteStyle = pw.TextStyle(
      font: italicFont,
      fontSize: 10,
      color: PdfColors.grey700,
    );

    // Generate a receipt number using timestamp and payment ID
    final receiptNumber =
        'RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${payment.id.substring(0, 4)}';

    // Format the timestamps
    final formattedPaymentDate =
        DateFormat('MMMM d, y - h:mm a').format(payment.paymentDate);
    final formattedGenerationDate =
        DateFormat('MMMM d, y - h:mm a').format(DateTime.now());
    final subscriptionPeriod =
        '${DateFormat('MMMM d, y').format(customer.subscriptionStart)} - ${DateFormat('MMMM d, y').format(customer.subscriptionEnd)}';

    // Create the PDF document
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    // Add the receipt page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Stack(
            children: [
              // Main content
              pw.Container(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header section with logo and company info
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(companyInfo['name'], style: titleStyle),
                            pw.SizedBox(height: 4),
                            pw.Text('Internet Service Provider',
                                style: subtitleStyle),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue900,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text(
                            'RECEIPT',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 18,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 20),

                    // Receipt info container
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Receipt Number', style: labelStyle),
                              pw.SizedBox(height: 4),
                              pw.Text(receiptNumber,
                                  style: valueStyle.copyWith(
                                      fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 8),
                              pw.Text('Date of Payment', style: labelStyle),
                              pw.SizedBox(height: 4),
                              pw.Text(formattedPaymentDate, style: valueStyle),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('Status', style: labelStyle),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: payment.isConfirmed
                                      ? PdfColors.green100
                                      : PdfColors.orange100,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(
                                  payment.isConfirmed ? 'CONFIRMED' : 'PENDING',
                                  style: valueStyle.copyWith(
                                    color: payment.isConfirmed
                                        ? PdfColors.green800
                                        : PdfColors.orange800,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text('Generation Date', style: labelStyle),
                              pw.SizedBox(height: 4),
                              pw.Text(formattedGenerationDate,
                                  style: valueStyle),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // Customer details
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER DETAILS', style: subheaderStyle),
                          pw.SizedBox(height: 12),
                          pw.Divider(color: PdfColors.grey300),
                          pw.SizedBox(height: 8),
                          _buildInfoRow('Customer Name', customer.name,
                              labelStyle, valueStyle),
                          _buildInfoRow('Contact', customer.contact, labelStyle,
                              valueStyle),
                          _buildInfoRow('WiFi Name', customer.wifiName,
                              labelStyle, valueStyle),
                          _buildInfoRow('Subscription Period',
                              subscriptionPeriod, labelStyle, valueStyle),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // Payment details
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAYMENT DETAILS', style: subheaderStyle),
                          pw.SizedBox(height: 12),
                          pw.Divider(color: PdfColors.grey300),
                          pw.SizedBox(height: 8),

                          // Payment amount with highlight
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue100,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('AMOUNT PAID', style: labelStyle),
                                pw.SizedBox(height: 8),
                                pw.Text(
                                  _currency.format(payment.amount),
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 20,
                                    color: PdfColors.blue900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 12),
                          _buildInfoRow(
                              'Plan Type',
                              payment.planType.name.toUpperCase(),
                              labelStyle,
                              valueStyle),
                          _buildInfoRow(
                              'Payment Method', 'Cash', labelStyle, valueStyle),
                          _buildInfoRow(
                              'Payment ID', payment.id, labelStyle, valueStyle),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 20),

                    // Referral information (if applicable)
                    if (referrer != null)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.purple50,
                          border: pw.Border.all(color: PdfColors.purple100),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('REFERRAL INFORMATION',
                                style: subheaderStyle.copyWith(
                                    color: PdfColors.purple900)),
                            pw.SizedBox(height: 8),
                            _buildInfoRow('Referred By', referrer.name,
                                labelStyle, valueStyle),
                            _buildInfoRow(
                              'Referral Reward',
                              '${_calculateReferralReward(referrer.planType, customer.planType).inDays} days free',
                              labelStyle,
                              valueStyle,
                            ),
                          ],
                        ),
                      ),

                    pw.SizedBox(height: 20),

                    // Referral code promotion
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue200),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('REFER A FRIEND & EARN FREE DAYS',
                              style: subheaderStyle),
                          pw.SizedBox(height: 12),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Your Referral Code:',
                                        style: labelStyle),
                                    pw.SizedBox(height: 4),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: pw.BoxDecoration(
                                        border: pw.Border.all(
                                            color: PdfColors.blue300),
                                        borderRadius:
                                            pw.BorderRadius.circular(4),
                                      ),
                                      child: pw.Text(
                                        customer.referralCode,
                                        style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 16,
                                          color: PdfColors.blue900,
                                        ),
                                      ),
                                    ),
                                    pw.SizedBox(height: 8),
                                    pw.Text(
                                      'Share with friends and earn:',
                                      style: noteStyle,
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Text(
                                      '• 7 days free for monthly plan referrals',
                                      style: noteStyle,
                                    ),
                                    pw.Text(
                                      '• 3 days free for weekly plan referrals',
                                      style: noteStyle,
                                    ),
                                    pw.Text(
                                      '• 1 day free for daily plan referrals',
                                      style: noteStyle,
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 16),
                              pw.BarcodeWidget(
                                data:
                                    'rcpt=$receiptNumber;amt=${payment.amount};cid=${customer.id};date=${payment.paymentDate.millisecondsSinceEpoch}',
                                barcode: pw.Barcode.qrCode(),
                                width: 80,
                                height: 80,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.Spacer(),

                    // Footer
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                            top: pw.BorderSide(color: PdfColors.grey300)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'Thank you for choosing Truthy Systems!',
                            style:
                                headerStyle.copyWith(color: PdfColors.blue700),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('Contact: ', style: labelStyle),
                              pw.Text(companyInfo['phone'], style: valueStyle),
                              pw.Text(' | ', style: valueStyle),
                              pw.Text(companyInfo['email'], style: valueStyle),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'This is a computer-generated receipt and does not require a signature.',
                            style: noteStyle,
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Watermark (subtle background text for authenticity)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: -0.3,
                    child: pw.Text(
                      'Truthy Systems',
                      style: pw.TextStyle(
                        color: PdfColors.grey100,
                        fontSize: 80,
                        font: boldFont,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf;
  }

  /// Shows a receipt preview dialog and provides options to share, save, or print
  static Future<void> previewReceipt({
    required BuildContext context,
    required Payment payment,
    required Customer customer,
  }) async {
    // First show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating receipt...'),
          ],
        ),
      ),
    );

    // Generate the receipt
    final pdf = await generateReceiptDocument(
      payment: payment,
      customer: customer,
    );

    // Close the loading dialog
    Navigator.of(context).pop();

    // Show the preview
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Receipt Preview'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) => pdf.save(),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  maxPageWidth: 800,
                  actions: [
                    PdfPreviewAction(
                      icon: const Icon(Icons.share),
                      onPressed: (context, _, pdfData) async {
                        final pdfU = await pdf.document.save();
                        await _shareReceipt(pdfU, customer.name, payment.id);
                      },
                    ),
                    PdfPreviewAction(
                      icon: const Icon(Icons.save_alt),
                      onPressed: (context, _, pdfData) async {
                        final pdfU = await pdf.document.save();
                        await _saveReceiptLocally(pdfU, payment.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Receipt saved to Downloads folder')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Legacy method for direct sharing without preview
  static Future<void> generateAndShareReceipt({
    required Payment payment,
    required Customer customer,
  }) async {
    final pdf = await generateReceiptDocument(
      payment: payment,
      customer: customer,
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/truthy_receipt_${payment.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Payment Receipt - ${customer.name}',
      subject: 'Truthy Systems - Internet Service Receipt',
    );
  }

  /// Helper method to build info rows in the receipt
  static pw.Row _buildInfoRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          child: pw.Text(label, style: labelStyle),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(value, style: valueStyle),
        ),
      ],
    );
  }

  /// Calculates the referral reward based on plan types
  static Duration _calculateReferralReward(
    PlanType referrerPlan,
    PlanType newCustomerPlan,
  ) {
    if (newCustomerPlan == PlanType.monthly) {
      return const Duration(days: 7);
    } else if (newCustomerPlan == PlanType.weekly) {
      return const Duration(days: 3);
    } else {
      return const Duration(days: 1);
    }
  }

  /// Shares the receipt using the device's share functionality
  static Future<void> _shareReceipt(
    Uint8List pdfData,
    String customerName,
    String paymentId,
  ) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/truthy_receipt_$paymentId.pdf');
    await file.writeAsBytes(pdfData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Payment Receipt - $customerName',
      subject: 'Truthy Systems - Internet Service Receipt',
    );
  }

  /// Saves the receipt to the device's download folder
  static Future<void> _saveReceiptLocally(
    Uint8List pdfData,
    String paymentId,
  ) async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory != null) {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath =
          '${directory.path}/Truthy_Receipt_${timestamp}_$paymentId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfData);
    }
  }
}
