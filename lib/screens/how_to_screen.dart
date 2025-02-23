import 'package:flutter/material.dart';

class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How To Use Truthy WiFi Manager'),
        backgroundColor: Colors.black.withOpacity(0.2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Getting Started',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Learn how to manage your WiFi subscriptions efficiently with Truthy WiFi Manager. Follow these steps to get the most out of the app.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Sections
            _buildSection(
              context,
              'Sign In or Register',
              [
                'Open the app and sign in with your email or phone number.',
                'New user? Tap "Create one" to register.',
                'Use biometric authentication if enabled for faster access.',
              ],
            ),
            _buildSection(
              context,
              'Add a Customer',
              [
                'From the Home screen, tap "Add Customer".',
                'Enter the customer’s name, contact, and optional referral code.',
                'Select a plan (Daily, Weekly, Monthly) and save.',
                'WiFi credentials will be generated automatically.',
              ],
            ),
            _buildSection(
              context,
              'Manage Payments',
              [
                'Go to "Payments" from the Home screen.',
                'Tap the "+" icon to add a payment for a customer.',
                'View payment history and generate receipts.',
              ],
            ),
            _buildSection(
              context,
              'Handle Downtime',
              [
                'Navigate to "Downtime" from the Home screen.',
                'Enter the downtime duration in hours and confirm.',
                'All active subscriptions will be extended automatically.',
              ],
            ),
            _buildSection(
              context,
              'Track Referrals',
              [
                'View a customer’s referral code in their details.',
                'Share it to earn free subscription days.',
                'Check referral stats from the customer detail screen.',
              ],
            ),
            _buildSection(
              context,
              'Monitor Insights',
              [
                'Visit "Retention" for churn and retention rates.',
                'Check "Billing Cycles" for income and profit summaries.',
                'Review expiring subscriptions under "Expiring".',
              ],
            ),
            const SizedBox(height: 24),
            // Support
            Text(
              'Need Help?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Contact our 24/7 support at truthysys@proton.me or +256-783-009649.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key + 1}. ', style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: Text(entry.value, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}