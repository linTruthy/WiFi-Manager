import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerShareView extends StatefulWidget {
  const CustomerShareView({super.key});

  @override
  State<CustomerShareView> createState() => _CustomerShareViewState();
}

class _CustomerShareViewState extends State<CustomerShareView> {
  Map<String, dynamic>? customerData;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> referrals = [];
  List<Map<String, dynamic>> downtimes = [];
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
    final userId = uri.queryParameters['uid'];
    String? customerId =
        uri.queryParameters['cid'] ?? uri.queryParameters['monospaceUid'];

    if (customerId != null && customerId.contains('?')) {
      customerId = customerId.substring(0, customerId.indexOf('?'));
    }
    if (userId == null || customerId == null) {
      setState(() {
        error = "Invalid link parameters. Missing user or customer ID.";
        loading = false;
      });
      return;
    }
    try {
      // Fetch customer data
      final customerDoc = await FirebaseFirestore.instance
          .collection('users/$userId/customers')
          .doc(customerId)
          .get();
      if (!customerDoc.exists) {
        print('users/$userId/customers/$customerId');
        setState(() {
          error = "Customer not found.";
          loading = false;
        });
        return;
      }
      customerData = customerDoc.data();
      if (customerData != null && customerData!['subscriptionEnd'] != null) {
        expiration = DateTime.parse(customerData!['subscriptionEnd']);
      } else {
        setState(() {
          error = "Subscription end date not found.";
          loading = false;
        });
        return;
      }

      // Fetch payments
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('users/$userId/payments')
          .where('customerId', isEqualTo: customerId)
          .orderBy('paymentDate', descending: true)
          .limit(5) // Limit to recent payments for brevity
          .get();
      payments = paymentsQuery.docs.map((doc) => doc.data()).toList();

      // Fetch referrals
      final referralsQuery = await FirebaseFirestore.instance
          .collection('users/$userId/referral_stats')
          .where('referredCustomerId', isEqualTo: customerId)
          .get();
      referrals = referralsQuery.docs.map((doc) => doc.data()).toList();

      // Fetch downtime logs (if available)
      final downtimeQuery = await FirebaseFirestore.instance
          .collection('users/$userId/downtime_logs')
          .where('affectedCustomers', arrayContains: customerId)
          .orderBy('timestamp', descending: true)
          .limit(3) // Limit to recent downtimes
          .get();
      downtimes = downtimeQuery.docs.map((doc) => doc.data()).toList();

      _startCountdown();
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Error fetching data: $e";
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
      if (remainingTime.isNegative) {
        countdownTimer?.cancel();
        error = "Your subscription has expired.";
      }
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorScreen()
              : _buildEnhancedContent(),
    );
  }

  Widget _buildEnhancedContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroHeader(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMainDashboard(),
                const SizedBox(height: 24),
                _buildUsageStats(),
                const SizedBox(height: 24),
                if (payments.isNotEmpty) _buildPaymentHistory(),
                const SizedBox(height: 24),
                _buildReferralSection(),
                if (downtimes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildDowntimeHistory(),
                ],
              ],
            ),
          ),
          _buildEnhancedFooter(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[900]!, Colors.blue[800]!],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Text(
                "Truthy Systems",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Experience Unlimited Possibilities",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureBadge(Icons.check_circle_outline, "99.9% Uptime"),
              _buildFeatureBadge(Icons.speed, "Premium Speed"),
              _buildFeatureBadge(Icons.support_agent, "24/7 Support"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMainDashboard() {
    final bool isActive = !remainingTime.isNegative;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Welcome, ${customerData?['name'] ?? 'Customer'}",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                _buildStatusChip(isActive),
              ],
            ),
            const SizedBox(height: 24),
            _buildSubscriptionTimer(),
            const SizedBox(height: 24),
            _buildConnectionDetails(),
            const SizedBox(height: 24),
            _buildPremiumFeatures(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? "Active" : "Expired",
        style: TextStyle(
          color: isActive ? Colors.green[700] : Colors.red[700],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubscriptionTimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              remainingTime.isNegative
                  ? "Subscription expired on ${DateFormat('MMM d, y').format(expiration!)}"
                  : "Time remaining: ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24)}h ${remainingTime.inMinutes.remainder(60)}m",
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDetails() {
    return Column(
      children: [
        _buildDetailRow(
          "WiFi Name",
          customerData?['wifiName'] ?? 'N/A',
          Icons.wifi,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          "Password",
          customerData?['currentPassword'] ?? 'N/A',
          Icons.lock,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          "Plan",
          customerData?['planType']?.toString().toUpperCase() ?? 'N/A',
          Icons.star,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Premium Benefits",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem("Unlimited Downloads"),
          _buildFeatureItem("Priority Customer Support"),
          _buildFeatureItem("Access to All Devices"),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Usage Statistics",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard("99.9%", "Uptime", Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard("50Mbps", "Speed", Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard("2", "Devices", Colors.purple),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, MaterialColor color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[50]!, Colors.blue[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Earn Free Days!",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    "Your Referral Code",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customerData?['referralCode'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildReferralRewards(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Implement share functionality
              },
              icon: const Icon(Icons.share),
              label: Text("Share & Earn",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralRewards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber[400], size: 20),
              const SizedBox(width: 8),
              Text(
                "Rewards",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRewardItem("7 Free Days - Monthly Plan Referral"),
          _buildRewardItem("3 Free Days - Weekly Plan Referral"),
          _buildRewardItem("1 Free Day - Daily Plan Referral"),
        ],
      ),
    );
  }

  Widget _buildRewardItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green[600], size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Payment History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                )),
            const SizedBox(height: 16),
            ...payments.map((payment) => _buildPaymentItem(payment)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payment,
              color: Colors.blue[700],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "UGX ${payment['amount']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  DateFormat('MMM d, y').format(
                    DateTime.parse(payment['paymentDate']),
                  ),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            payment['isConfirmed'] ? Icons.check_circle : Icons.pending,
            color:
                payment['isConfirmed'] ? Colors.green[600] : Colors.orange[600],
          ),
        ],
      ),
    );
  }

  Widget _buildDowntimeHistory() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Service Updates",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...downtimes.map((downtime) => _buildDowntimeItem(downtime)),
          ],
        ),
      ),
    );
  }

  Widget _buildDowntimeItem(Map<String, dynamic> downtime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange[700],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Downtime Duration: ${downtime['durationHours']} hours",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey[600]),
                ),
                Text(
                  DateFormat('MMM d, y - h:mm a').format(
                    DateTime.parse(downtime['timestamp']),
                  ),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFooter() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Text(
            "Truthy Systems",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Delivering Premium WiFi Solutions",
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                "truthysys@proton.me",
                style: TextStyle(
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                "+256-783-009649",
                style: TextStyle(
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              error!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red[400],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
