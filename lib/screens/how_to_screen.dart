import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HowToScreen extends StatefulWidget {
  const HowToScreen({super.key});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  final Map<String, bool> _expandedSections = {};
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final sections = [
      _buildGettingStartedSection(colorScheme),
      _buildCustomerManagementSection(colorScheme),
      _buildBillingSection(colorScheme),
      _buildNotificationsSection(colorScheme),
      _buildReferralSection(colorScheme),
      _buildTroubleshootingSection(colorScheme),
    ];

    // Filter sections based on search query
    final filteredSections = _searchQuery.isEmpty 
        ? sections 
        : sections.where((section) {
            final sectionContent = section.toString().toLowerCase();
            return sectionContent.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('How To Use Truthy WiFi Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search help topics',
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video tutorials',
            onPressed: () => _showVideoTutorialsDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Navigation sidebar for larger screens
            if (MediaQuery.of(context).size.width > 800)
              SizedBox(
                width: 250,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Quick Navigation',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const Divider(),
                        _buildNavItem(context, 'Getting Started', Icons.play_arrow, 0),
                        _buildNavItem(context, 'Customer Management', Icons.people, 1),
                        _buildNavItem(context, 'Billing & Payments', Icons.payment, 2),
                        _buildNavItem(context, 'Notifications', Icons.notifications, 3),
                        _buildNavItem(context, 'Referral Program', Icons.share, 4),
                        _buildNavItem(context, 'Troubleshooting', Icons.build, 5),
                        const Divider(),
                        _buildSupportSection(context),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Main content
            Expanded(
              child: filteredSections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, 
                             size: 64, 
                             color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No results found for "$_searchQuery"',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      HapticFeedback.mediumImpact();
                      // Simulating refresh
                      await Future.delayed(const Duration(milliseconds: 800));
                    },
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_searchQuery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Search results for "$_searchQuery"',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear'),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                        // Welcome card
                        if (_searchQuery.isEmpty)
                          _buildWelcomeCard(context),
                        
                        // Content sections
                        ...filteredSections,
                        
                        const SizedBox(height: 16),
                        
                        // Feedback card
                        if (_searchQuery.isEmpty)
                          _buildFeedbackCard(context),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        tooltip: 'Back to top',
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String title, IconData icon, int index) {
    return Semantics(
      button: true,
      label: 'Navigate to $title section',
      child: InkWell(
        onTap: () {
          final screenHeight = MediaQuery.of(context).size.height;
          // This is an approximation, will need adjustment based on actual layout
          final offsetEstimate = index * screenHeight * 0.4;
          _scrollController.animateTo(
            offsetEstimate, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need Help?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.mail_outline),
            label: const Text('Contact Support'),
            onPressed: () {
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'truthysys@proton.me',
                queryParameters: {
                  'subject': 'Truthy WiFi Manager Support Request',
                }
              );
              launchUrl(emailLaunchUri);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.phone),
            label: const Text('+256-783-009649'),
            onPressed: () {
              final Uri telLaunchUri = Uri(
                scheme: 'tel',
                path: '+256783009649',
              );
              launchUrl(telLaunchUri);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Truthy WiFi Manager Guide',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Everything you need to know about managing your WiFi subscriptions',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'This guide will help you efficiently manage your WiFi subscriptions and provide the best service to your customers. Learn how to track payments, handle referrals, and more.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickStartChip(context, 'Add Customer', Icons.person_add, 1),
                _buildQuickStartChip(context, 'Process Payment', Icons.payment, 2),
                _buildQuickStartChip(context, 'Track Referrals', Icons.share, 4),
                _buildQuickStartChip(context, 'Billing', Icons.receipt_long, 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartChip(BuildContext context, String label, IconData icon, int targetSectionIndex) {
    return Semantics(
      button: true,
      label: 'Quick start guide for $label',
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          final screenHeight = MediaQuery.of(context).size.height;
          final offsetEstimate = targetSectionIndex * screenHeight * 0.4;
          _scrollController.animateTo(
            offsetEstimate, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut
          );
          
          // Expand the target section
          setState(() {
            final sectionKeys = ['customerManagement', 'billing', 'notifications', 'referral', 'troubleshooting'];
            if (targetSectionIndex - 1 < sectionKeys.length) {
              _expandedSections[sectionKeys[targetSectionIndex - 1]] = true;
            }
          });
        },
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Was this guide helpful?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'We\'re always looking to improve our documentation. If you have any suggestions or found something unclear, please let us know.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Yes, it helped'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thanks for your feedback!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.thumb_down),
                  label: const Text('Needs improvement'),
                  onPressed: () {
                    _showFeedbackDialog(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please tell us how we can improve this guide:'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your feedback here...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback! We\'ll review it shortly.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Help Topics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Type to search...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('SEARCH'),
          ),
        ],
      ),
    );
  }

  void _showVideoTutorialsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Tutorials'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildVideoTutorialItem(
                context,
                'Getting Started with Truthy WiFi Manager',
                'Learn the basics in 5 minutes',
                '5:32',
              ),
              const Divider(),
              _buildVideoTutorialItem(
                context,
                'Managing Customers and Subscriptions',
                'Complete guide to customer management',
                '7:48',
              ),
              const Divider(),
              _buildVideoTutorialItem(
                context,
                'Payment Processing and Billing',
                'How to handle payments efficiently',
                '6:15',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTutorialItem(
    BuildContext context, 
    String title, 
    String description, 
    String duration
  ) {
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.play_arrow),
      ),
      title: Text(title),
      subtitle: Text(description),
      trailing: Text(
        duration,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video tutorials coming soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ColorScheme colorScheme,
    required String sectionKey,
  }) {
    final isExpanded = _expandedSections[sectionKey] ?? false;
    
    return Semantics(
      container: true,
      label: '$title section, ${isExpanded ? 'expanded' : 'collapsed'}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[sectionKey] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon, color: colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String stepTitle, String description, IconData icon, {String? tip}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description),
                if (tip != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TIP: $tip',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGettingStartedSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Getting Started',
      icon: Icons.play_arrow,
      sectionKey: 'gettingStarted',
      colorScheme: colorScheme,
      children: [
        Text(
          'Welcome to Truthy WiFi Manager! Follow these steps to get started with the application.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        _buildStepItem(
          'Sign In or Register',
          'Open the app and sign in with your email or phone number. New user? Tap "Create one" to register.',
          Icons.login,
          tip: 'Enable biometric authentication for faster access in the future.',
        ),
        
        _buildStepItem(
          'Navigate the Dashboard',
          'The home screen provides an overview of your subscriptions, payments, and expiring accounts.',
          Icons.dashboard,
        ),
        
        _buildStepItem(
          'Customize Settings',
          'Go to Settings to configure your notification preferences, default prices, and app behavior.',
          Icons.settings,
          tip: 'Set up price defaults right away to make adding new customers faster.',
        ),
        
        const Divider(height: 32),
        
        ExpansionTile(
          title: const Text('View System Requirements'),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            _buildRequirementItem('Operating System', 'Android 6.0+ or iOS 12.0+'),
            _buildRequirementItem('Memory', 'Minimum 2GB RAM'),
            _buildRequirementItem('Storage', 'At least 100MB free space'),
            _buildRequirementItem('Internet Connection', 'Required for synchronization'),
            _buildRequirementItem('Permissions', 'Notifications, Storage, Phone'),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildCustomerManagementSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Customer Management',
      icon: Icons.people,
      sectionKey: 'customerManagement',
      colorScheme: colorScheme,
      children: [
        Text(
          'Learn how to effectively manage your customers and their subscriptions.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        _buildStepItem(
          'Add a New Customer',
          'From the Home screen, tap "Add Customer" button. Enter customer details like name, contact info, and select a subscription plan.',
          Icons.person_add,
          tip: 'Use the auto-generated WiFi name and password or customize them as needed.',
        ),
        
        _buildStepItem(
          'View Customer Details',
          'Tap on any customer in the Customers list to view their detailed information, including subscription status and payment history.',
          Icons.info_outline,
        ),
        
        _buildStepItem(
          'Edit Customer Information',
          'From the customer details screen, tap the edit icon to modify customer information, change plan, or update credentials.',
          Icons.edit,
        ),
        
        _buildStepItem(
          'Handle Inactive Customers',
          'Access inactive customers from the menu. You can reactivate customers or permanently delete their records.',
          Icons.person_off,
          tip: 'Consider sending a special offer to win back inactive customers.',
        ),
        
        const Divider(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Best Practices',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              _buildBestPracticeItem('Keep customer contact information updated'),
              _buildBestPracticeItem('Regularly check for expiring subscriptions'),
              _buildBestPracticeItem('Document any special arrangements or notes'),
              _buildBestPracticeItem('Tag VIP customers for special treatment'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBestPracticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildBillingSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Billing & Payments',
      icon: Icons.payment,
      sectionKey: 'billing',
      colorScheme: colorScheme,
      children: [
        Text(
          'Learn how to handle payments, generate receipts, and manage billing cycles.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        _buildStepItem(
          'Process a Payment',
          'Navigate to the customer\'s profile and click "Add Payment", or go to Payments screen and select the customer there.',
          Icons.payment,
        ),
        
        _buildStepItem(
          'Generate Receipt',
          'After recording a payment, use the receipt button to generate a professional receipt that can be shared with the customer.',
          Icons.receipt,
          tip: 'Share receipts immediately to improve customer satisfaction.',
        ),
        
        _buildStepItem(
          'Track Billing Cycles',
          'Use the Billing Cycles feature to track your WiFi expenses and customer payments over specific periods.',
          Icons.date_range,
        ),
        
        _buildStepItem(
          'Handle Overdue Payments',
          'Identify customers with expired subscriptions and send reminders or take appropriate action.',
          Icons.warning,
        ),
        
        const Divider(height: 32),
        
        ExpansionTile(
          title: const Text('Payment Reports'),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Truthy WiFi Manager provides several ways to analyze your payment data:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildReportTypeItem(
              'Daily Summary',
              'View payments collected each day',
              Icons.today,
            ),
            _buildReportTypeItem(
              'Monthly Report',
              'Analyze monthly revenue trends',
              Icons.calendar_view_month,
            ),
            _buildReportTypeItem(
              'Plan-wise Analysis',
              'Compare revenue from different plan types',
              Icons.pie_chart,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTypeItem(String title, String description, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      dense: true,
    );
  }

  Widget _buildNotificationsSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Notification Management',
      icon: Icons.notifications,
      sectionKey: 'notifications',
      colorScheme: colorScheme,
      children: [
        Text(
          'Configure and manage notification settings to stay informed about expiring subscriptions.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        _buildStepItem(
          'Configure Notification Settings',
          'Go to Settings > Notification Settings to customize when notifications should be sent for different plan types.',
          Icons.settings_applications,
        ),
        
        _buildStepItem(
          'View Scheduled Notifications',
          'Check the Scheduled Reminders screen to see all upcoming notification alerts.',
          Icons.schedule,
          tip: 'You can cancel scheduled notifications if needed.',
        ),
        
        _buildStepItem(
          'Handle App Permissions',
          'Ensure Truthy WiFi Manager has the necessary permissions to send notifications on your device.',
          Icons.app_settings_alt,
        ),
        
        const Divider(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommended Notification Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              _buildNotificationSettingItem('Daily Plans', 'Same day (a few hours before expiry)'),
              _buildNotificationSettingItem('Weekly Plans', '1 day before expiry'),
              _buildNotificationSettingItem('Monthly Plans', '3 days before expiry'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettingItem(String planType, String timing) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              planType,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(timing)),
        ],
      ),
    );
  }

  Widget _buildReferralSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Referral Program',
      icon: Icons.share,
      sectionKey: 'referral',
      colorScheme: colorScheme,
      children: [
        Text(
          'Learn how to leverage the built-in referral system to grow your customer base.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        _buildStepItem(
          'Understanding Referrals',
          'Each customer has a unique referral code that they can share with others. When new customers sign up using this code, both parties receive benefits.',
          Icons.lightbulb_outline,
        ),
        
        _buildStepItem(
          'Sharing Referral Codes',
          'Access a customer\'s profile and use the "Share Referral Code" button to generate a message with their unique code.',
          Icons.send,
          tip: 'Encourage customers to share their code on social media for maximum reach.',
        ),
        
        _buildStepItem(
          'Tracking Referrals',
          'View a customer\'s referral statistics to see how many new customers they\'ve brought in and the rewards they\'ve earned.',
          Icons.bar_chart,
        ),
        
        _buildStepItem(
          'Managing Rewards',
          'The system automatically applies referral rewards by extending subscription end dates when a new customer uses a referral code.',
          Icons.card_giftcard,
        ),
        
        const Divider(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Referral Reward Structure',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 12),
              _buildRewardItem('For Monthly Plan Referrals', '7 days free service'),
              _buildRewardItem('For Weekly Plan Referrals', '3 days free service'),
              _buildRewardItem('For Daily Plan Referrals', '1 day free service'),
              const SizedBox(height: 8),
              const Text(
                'Note: Both the referrer and the new customer benefit from the program.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardItem(String referralType, String reward) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              referralType,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(reward)),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection(ColorScheme colorScheme) {
    return _buildExpandableSection(
      title: 'Troubleshooting',
      icon: Icons.build,
      sectionKey: 'troubleshooting',
      colorScheme: colorScheme,
      children: [
        Text(
          'Solutions for common issues you might encounter while using Truthy WiFi Manager.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 16),
        
        ExpansionTile(
          title: const Text('App Performance Issues'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildTroubleshootingItem(
              'App is running slowly',
              'Clear cache, ensure you have adequate storage space, and restart the app.',
            ),
            _buildTroubleshootingItem(
              'App crashes frequently',
              'Update to the latest version, restart your device, or reinstall the application.',
            ),
          ],
        ),
        
        ExpansionTile(
          title: const Text('Notification Problems'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildTroubleshootingItem(
              'Not receiving notifications',
              'Check notification permissions in your device settings and ensure the app has background permissions.',
            ),
            _buildTroubleshootingItem(
              'Duplicate notifications',
              'Go to Settings > Notification Settings and toggle notifications off and back on.',
            ),
          ],
        ),
        
        ExpansionTile(
          title: const Text('Subscription & Payment Issues'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildTroubleshootingItem(
              'Cannot add payment',
              'Verify that you have selected a customer and entered a valid amount.',
            ),
            _buildTroubleshootingItem(
              'Subscription dates incorrect',
              'Edit the customer and manually adjust their subscription start and end dates.',
            ),
          ],
        ),
        
        ExpansionTile(
          title: const Text('Data Synchronization'),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildTroubleshootingItem(
              'Changes not saving',
              'Check your internet connection and ensure you\'re logged in correctly.',
            ),
            _buildTroubleshootingItem(
              'Missing data after login',
              'Verify you\'re using the correct account and check your internet connection.',
            ),
          ],
        ),
        
        const Divider(height: 32),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Still having issues?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'If you\'re still experiencing problems after trying these troubleshooting steps, please contact our support team:',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('truthysys@proton.me'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('+256-783-009649'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingItem(String problem, String solution) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problem,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Solution: $solution',
            style: const TextStyle(fontSize: 14),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}