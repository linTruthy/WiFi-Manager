import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerShareView extends StatefulWidget {
  const CustomerShareView({super.key});

  @override
  _CustomerShareViewState createState() => _CustomerShareViewState();
}

class _CustomerShareViewState extends State<CustomerShareView> {
  Map<String, dynamic>? customerData;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> referrals = [];
  DateTime? expiration;
  bool loading = true;
  String? error;
  Timer? countdownTimer;
  Duration remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uri = Uri.base;
    final customerId = uri.queryParameters['customerId'];
    final expParam = uri.queryParameters['expiration'];

    if (customerId == null) {
      //|| expParam == null) {
      setState(() {
        error = "Invalid link parameters.";
        loading = false;
      });
      return;
    }

    try {
      expiration = DateTime.now();
      //parse(expParam);

      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .get();

      if (!customerDoc.exists) {
        setState(() {
          error = "Customer not found.";
          loading = false;
        });
        return;
      }

      customerData = customerDoc.data();

      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('customerId', isEqualTo: customerId)
          .get();
      payments = paymentsQuery.docs.map((doc) => doc.data()).toList();

      final referralsQuery = await FirebaseFirestore.instance
          .collection('referrals')
          .where('customerId', isEqualTo: customerId)
          .get();
      referrals = referralsQuery.docs.map((doc) => doc.data()).toList();

      _startCountdown();

      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _startCountdown() {
    if (expiration == null) return;

    _updateRemainingTime();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (expiration == null) return;

    final now = DateTime.now();
    setState(() {
      remainingTime = expiration!.difference(now);
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(child: Text(error!)),
      );
    }

    // if (expiration != null && remainingTime.isNegative) {
    //   return const Scaffold(
    //     body: Center(child: Text("This link has expired.")),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(title: const Text("Customer Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, ${customerData?['name'] ?? 'Customer'}",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              "Link expires in: ${remainingTime.inHours}h ${remainingTime.inMinutes.remainder(60)}m ${remainingTime.inSeconds.remainder(60)}s",
              style: const TextStyle(color: Colors.redAccent),
            ),
            const Divider(),
            Text("Contact: ${customerData?['contact'] ?? ''}"),
            Text("WiFi Name: ${customerData?['wifiName'] ?? ''}"),
            Text("Plan: ${customerData?['planType'] ?? ''}"),
            const SizedBox(height: 16),
            Text("Referral Code: ${customerData?['referralCode'] ?? ''}"),
            const Divider(),
            const Text(
              "Payments:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...payments.map(
              (p) => Text("Amount: ${p['amount']} on ${p['paymentDate']}"),
            ),
            const Divider(),
            const Text(
              "Referrals:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...referrals.map(
              (r) => Text("Referred by: ${r['referrerName'] ?? 'N/A'}"),
            ),
          ],
        ),
      ),
    );
  }
}
