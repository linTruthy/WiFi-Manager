import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class CustomerShareView extends StatefulWidget {
  const CustomerShareView({super.key});

  @override
  State<CustomerShareView> createState() => _CustomerShareViewState();
}

class _CustomerShareViewState extends State<CustomerShareView>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? customerData;
  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> referrals = [];
  List<Map<String, dynamic>> downtimes = [];
  DateTime? expiration;
  bool loading = true;
  String? error;
  Timer? countdownTimer;
  Duration remainingTime = Duration.zero;

  // For managing tab navigation
  late TabController _tabController;
  final List<String> _tabs = ['Overview', 'Payments', 'Status', 'Support'];

  // For animations
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });

      final uri = Uri.base;
      final userId = uri.queryParameters['uid'];
      String? customerId =
          uri.queryParameters['cid'] ?? uri.queryParameters['monospaceUid'];

      if (customerId != null && customerId.contains('?')) {
        customerId = customerId.substring(0, customerId.indexOf('?'));
      }

      if (userId == null || customerId == null) {
        setState(() {
          error =
              "Invalid link or missing information. Please check your URL and try again.";
          loading = false;
        });
        return;
      }

      // Fetch customer data
      final customerDoc = await FirebaseFirestore.instance
          .collection('users/$userId/customers')
          .doc(customerId)
          .get();

      if (!customerDoc.exists) {
        setState(() {
          error =
              "Customer not found. The information may have been removed or is no longer accessible.";
          loading = false;
        });
        return;
      }

      customerData = customerDoc.data();

      if (customerData != null && customerData!['subscriptionEnd'] != null) {
        expiration = DateTime.parse(customerData!['subscriptionEnd']);

        // Process additional data
        await Future.wait([
          _fetchPayments(userId, customerId),
          _fetchReferrals(userId, customerId),
          _fetchDowntimes(userId, customerId),
        ]);

        // Start countdown timer
        _startCountdown();
        _animationController.forward();
      } else {
        setState(() {
          error = "Subscription information not available.";
        });
      }
    } catch (e) {
      setState(() {
        error =
            "Something went wrong while loading your information. Please try again later.";
        print("Error fetching data: $e");
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _fetchPayments(String userId, String customerId) async {
    final paymentsQuery = await FirebaseFirestore.instance
        .collection('users/$userId/payments')
        .where('customerId', isEqualTo: customerId)
        .orderBy('paymentDate', descending: true)
        .limit(5)
        .get();

    payments = paymentsQuery.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _fetchReferrals(String userId, String customerId) async {
    final referralsQuery = await FirebaseFirestore.instance
        .collection('users/$userId/referral_stats')
        .where('referredCustomerId', isEqualTo: customerId)
        .get();

    referrals = referralsQuery.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _fetchDowntimes(String userId, String customerId) async {
    final downtimeQuery = await FirebaseFirestore.instance
        .collection('users/$userId/downtime_logs')
        .where('affectedCustomers', arrayContains: customerId)
        .orderBy('timestamp', descending: true)
        .limit(3)
        .get();

    downtimes = downtimeQuery.docs.map((doc) => doc.data()).toList();
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

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? _buildLoadingScreen()
          : (error != null ? _buildErrorScreen() : _buildMainContent()),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Company logo or placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            "Truthy Systems",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            "Loading your subscription details...",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.indigo.shade900],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Company logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 64, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Try Again"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Add contact support action
                    _launchEmailSupport();
                  },
                  child: const Text(
                    "Contact Support",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchEmailSupport() {
    final Uri emailLaunchUri =
        Uri(scheme: 'mailto', path: 'truthysys@proton.me', queryParameters: {
      'subject': 'Help with WiFi Subscription',
      'body':
          'I need help with my subscription. My details are not loading correctly.'
    });

    // Use url_launcher to open email client
    // This is a placeholder - in a real implementation, you would use
    // url_launcher package to launch the email
    print(emailLaunchUri.toString());
  }

  Widget _buildMainContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: Colors.blue.shade900,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                customerData?['name'] ?? 'Customer',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade900, Colors.blue.shade800],
                      ),
                    ),
                  ),

                  // Pattern overlay
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              'https://www.transparenttextures.com/patterns/cubes.png',
                            ),
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Company logo and info at the top
                  Positioned(
                    top: 40,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.wifi,
                              color: Colors.blue.shade900, size: 24),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Truthy Systems",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Subscription status
                  Positioned(
                    bottom: 70,
                    left: 16,
                    child: _buildSubscriptionStatus(),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),
        ];
      },
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildPaymentsTab(),
            _buildStatusTab(),
            _buildSupportTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatus() {
    final bool isActive = !remainingTime.isNegative;
    Color statusColor = isActive ? Colors.green : Colors.red;

    String statusText = isActive ? "Active" : "Expired";

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: statusColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isActive)
          Text(
            "${remainingTime.inDays}d ${remainingTime.inHours.remainder(24)}h remaining",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subscription Timer Card
          _buildSubscriptionTimerCard(),
          const SizedBox(height: 24),

          // WiFi Credentials Card
          _buildWifiCredentialsCard(),
          const SizedBox(height: 24),

          // Premium Features Card
          _buildPremiumFeaturesCard(),
          const SizedBox(height: 24),

          // Referral Program Card
          _buildReferralProgramCard(),
          const SizedBox(height: 32),

          // Company Info Footer
          _buildCompanyFooter(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTimerCard() {
    final bool isActive = !remainingTime.isNegative;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [Colors.blue.shade50, Colors.blue.shade100]
                : [Colors.red.shade50, Colors.red.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color:
                        isActive ? Colors.blue.shade800 : Colors.red.shade800,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Subscription Status",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isActive ? Colors.blue.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isActive) ...[
                // Subscription active
                _buildTimerDisplay(),
                const SizedBox(height: 16),
                _buildDateRangeInfo(),
              ] else ...[
                // Subscription expired
                _buildExpiredMessage(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(remainingTime.inDays.toString(), "DAYS"),
        _buildTimeSeparator(),
        _buildTimeUnit(
            remainingTime.inHours.remainder(24).toString().padLeft(2, '0'),
            "HOURS"),
        _buildTimeSeparator(),
        _buildTimeUnit(
            remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0'),
            "MINUTES"),
      ],
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ":",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Your Plan Ends On:",
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMMM d, y - h:mm a').format(expiration!),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Plan Type: ${customerData?['planType']?.toString().toUpperCase() ?? 'N/A'}",
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredMessage() {
    final daysSinceExpiry = -remainingTime.inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.red.shade800,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          "Your Subscription Has Expired",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Expired on ${DateFormat('MMMM d, y').format(expiration!)} ($daysSinceExpiry days ago)",
          style: TextStyle(
            fontSize: 14,
            color: Colors.red.shade800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            // This would typically open a renewal action
            // For now, just show a message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Contact your service provider to renew your subscription"),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.refresh),
          label: const Text("Contact to Renew"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildWifiCredentialsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Your WiFi Credentials",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    final credentials =
                        "WiFi Name: ${customerData?['wifiName'] ?? 'N/A'}\nPassword: ${customerData?['currentPassword'] ?? 'N/A'}";
                    _copyToClipboard(
                        credentials, "WiFi credentials copied to clipboard");
                  },
                  icon: const Icon(Icons.copy),
                  tooltip: "Copy credentials",
                ),
              ],
            ),
            const SizedBox(height: 16),

            // WiFi Name
            _buildCredentialRow(
              "WiFi Name",
              customerData?['wifiName'] ?? 'N/A',
              Icons.router,
              Colors.blue.shade700,
            ),

            const Divider(height: 24),

            // Password with visibility toggle
            _buildPasswordRow(
              "Password",
              customerData?['currentPassword'] ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(
      String label, String value, IconData icon, Color iconColor) {
    return Semantics(
      label: "$label: $value",
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        _copyToClipboard(value, "$label copied to clipboard"),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // State for password visibility
  bool _passwordVisible = false;

  Widget _buildPasswordRow(String label, String value) {
    return Semantics(
      label: "$label: $value",
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _passwordVisible ? value : '••••••••',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          _passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          _copyToClipboard(value, "$label copied to clipboard"),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.copy,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeaturesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade500, Colors.indigo.shade700],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    "Premium Benefits",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildFeatureItem("High-Speed Connection (Up to 50Mbps)"),
              _buildFeatureItem("Connect Multiple Devices Simultaneously"),
              _buildFeatureItem("24/7 Technical Support"),
              _buildFeatureItem("99.9% Uptime Guarantee"),
              _buildFeatureItem("Priority Bandwidth Allocation"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralProgramCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade50, Colors.indigo.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  Text(
                    "Referral Program",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Share your referral code with friends and earn up to 7 days of free service for each friend who joins.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Referral code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Your Referral Code",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          customerData?['referralCode'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _copyToClipboard(
                            customerData?['referralCode'] ?? 'N/A',
                            "Referral code copied to clipboard",
                          ),
                          icon: const Icon(Icons.copy),
                          tooltip: "Copy referral code",
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Rewards explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star,
                            color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Reward Details",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRewardItem("7 Free Days for Monthly Plan Referrals"),
                    _buildRewardItem("3 Free Days for Weekly Plan Referrals"),
                    _buildRewardItem("1 Free Day for Daily Plan Referrals"),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Share button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      'Join Truthy WiFi using my referral code: ${customerData?['referralCode']}',
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text("Share Your Code"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green.shade600, size: 14),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    if (payments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payment,
        title: "No Payment History",
        message: "Your payment history will appear here",
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Payments",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Payment items
          ...payments.map((payment) => _buildPaymentItem(payment)).toList(),

          // Total section
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildTotalSection(payments),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final paymentDate = DateTime.parse(payment['paymentDate']);
    final amount = payment['amount'] as double;
    final isConfirmed = payment['isConfirmed'] as bool;
    final planType = payment['planType'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.receipt,
            color: Colors.green.shade600,
          ),
        ),
        title: Text(
          'UGX ${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM d, yyyy').format(paymentDate),
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Plan: ${planType.toString().toUpperCase()}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            isConfirmed ? 'Confirmed' : 'Pending',
            style: TextStyle(
              color:
                  isConfirmed ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 12,
            ),
          ),
          backgroundColor:
              isConfirmed ? Colors.green.shade50 : Colors.orange.shade50,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTotalSection(List<Map<String, dynamic>> payments) {
    final totalAmount = payments.fold<double>(
        0, (sum, payment) => sum + (payment['amount'] as double));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Payments",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "UGX ${totalAmount.toStringAsFixed(0)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Last ${payments.length} payment(s)",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage Statistics
          _buildUsageStatsCard(),
          const SizedBox(height: 24),

          // Downtime History
          _buildDowntimeHistoryCard(),
          const SizedBox(height: 24),

          // System Status
          _buildSystemStatusCard(),
        ],
      ),
    );
  }

  Widget _buildUsageStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_chart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Usage Statistics",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard("99.9%", "Uptime", Colors.green),
                ),
                Expanded(
                  child: _buildStatCard("50Mbps", "Max Speed", Colors.blue),
                ),
                Expanded(
                  child: _buildStatCard("2", "Devices", Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // This would typically show usage graphs or more detailed stats
            // For now, just a placeholder message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Your connection is running at optimal speeds. Average uptime this month has been excellent at 99.9%.",
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, MaterialColor color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
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

  Widget _buildDowntimeHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Downtime History",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (downtimes.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "No downtime recorded",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...downtimes
                  .map((downtime) => _buildDowntimeItem(downtime))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDowntimeItem(Map<String, dynamic> downtime) {
    final timestamp = DateTime.parse(downtime['timestamp'] as String);
    final durationHours = downtime['durationHours'] as num;
    final reason = downtime['reason'] as String? ?? 'Unspecified';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.orange.shade800,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Duration: ${durationHours.toStringAsFixed(1)} hours",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMM d, y - h:mm a').format(timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "Reason: $reason",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                // Show if compensation was applied
                if (downtime['compensationApplied'] == true)
                  Chip(
                    label: const Text(
                      "Compensation Applied",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: Colors.green.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.network_check, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                const Text(
                  "System Status",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSystemStatusItem(
              "Network",
              "Operational",
              Colors.green,
              "All services running normally",
            ),
            _buildSystemStatusItem(
              "Bandwidth",
              "Optimal",
              Colors.green,
              "Full speed available",
            ),
            _buildSystemStatusItem(
              "Scheduled Maintenance",
              "None",
              Colors.blue,
              "No maintenance planned",
            ),
            const SizedBox(height: 8),
            // Last checked timestamp
            Text(
              "Last updated: ${DateFormat('MMM d, y - h:mm a').format(DateTime.now())}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusItem(
      String label, String status, MaterialColor color, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: color.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: color.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade600,
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

  Widget _buildSupportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Support Card
          _buildContactSupportCard(),
          const SizedBox(height: 24),

          // FAQ Card
          _buildFaqCard(),
          const SizedBox(height: 24),

          // About Company Card
          _buildAboutCompanyCard(),
        ],
      ),
    );
  }

  Widget _buildContactSupportCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Contact Support",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Our support team is available 24/7 to assist with any questions or issues.",
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildContactMethod(
              icon: Icons.phone,
              title: "Phone",
              value: "+256-783-009649",
              onTap: () {
                // Launch phone app
                // This is a placeholder - would use url_launcher in a real app
                _copyToClipboard(
                  "+256-783-009649",
                  "Phone number copied to clipboard",
                );
              },
            ),
            const Divider(height: 24),
            _buildContactMethod(
              icon: Icons.email,
              title: "Email",
              value: "truthysys@proton.me",
              onTap: () {
                // Launch email app
                // This is a placeholder - would use url_launcher in a real app
                _copyToClipboard(
                  "truthysys@proton.me",
                  "Email address copied to clipboard",
                );
              },
            ),
            const Divider(height: 24),
            _buildContactMethod(
              icon: Icons.message,
              title: "WhatsApp",
              value: "Message Us",
              onTap: () {
                // Launch WhatsApp
                // This is a placeholder - would use url_launcher in a real app
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Opening WhatsApp..."),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethod({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.question_answer, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  "Frequently Asked Questions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFaqItem(
              "How many devices can I connect?",
              "Your plan allows for up to 2 devices to be connected simultaneously.",
            ),
            _buildFaqItem(
              "What happens if my subscription expires?",
              "Your WiFi access will be temporarily suspended until you renew your subscription.",
            ),
            _buildFaqItem(
              "How do I renew my subscription?",
              "Contact your service provider or use the referral program to earn free days.",
            ),
            _buildFaqItem(
              "Is there a data usage limit?",
              "No, all our plans come with unlimited data usage.",
            ),
          ],
        ),
      ),
    );
  }

  // State for expanded FAQ items
  Set<int> _expandedFaqItems = {};

  Widget _buildFaqItem(String question, String answer) {
    final index = question.hashCode;
    final isExpanded = _expandedFaqItems.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedFaqItems.add(index);
              } else {
                _expandedFaqItems.remove(index);
              }
            });
          },
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCompanyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Text(
                  "About Truthy Systems",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Truthy Systems is your trusted partner in delivering reliable, high-speed WiFi solutions tailored for both individuals and businesses. Our mission is to empower users with seamless internet access while simplifying subscription management.",
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    "Our Promise",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We guarantee 99.9% uptime, fast speeds, and exceptional customer service.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Truthy Systems",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Premium WiFi Solutions",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "truthysys@proton.me",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "+256-783-009649",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "© ${DateTime.now().year} Truthy Systems. All rights reserved.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
