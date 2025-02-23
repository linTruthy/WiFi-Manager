
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Truthy Systems'),
        backgroundColor: Colors.black.withOpacity(0.2),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Welcome to Truthy Systems',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Introduction
            Text(
              'Truthy Systems is your trusted partner in delivering reliable, high-speed WiFi solutions tailored for both individuals and businesses. Our mission is to empower users with seamless internet access while simplifying subscription management for providers through innovative technology.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Our Story
            Text(
              'Our Story',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Founded with a vision to bridge connectivity gaps, Truthy Systems combines cutting-edge software with exceptional customer service. Our WiFi Manager app is designed to streamline subscription tracking, payment processing, and customer engagement, ensuring uninterrupted service and satisfaction.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            // Key Features
            Text(
              'Key Features',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildFeatureItem(context, 'Customer Management', 'Easily add, edit, and track customer subscriptions.'),
            _buildFeatureItem(context, 'Billing & Payments', 'Monitor billing cycles and process payments effortlessly.'),
            _buildFeatureItem(context, 'Referral Program', 'Earn rewards by inviting others to join Truthy WiFi.'),
            _buildFeatureItem(context, 'Real-Time Insights', 'Access retention stats and revenue summaries.'),
            const SizedBox(height: 24),
            // Contact Info
            Text(
              'Contact Us',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Email: truthysys@proton.me\nPhone: +256-783-009649',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


