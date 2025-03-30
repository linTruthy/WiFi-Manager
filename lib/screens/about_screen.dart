import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Truthy Systems'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share this app',
            onPressed: () => _shareApp(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: BackgroundPatternPainter(
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero section
                  _buildHeroSection(context),
                  
                  // Mission & Vision
                  _buildMissionSection(context),
                  
                  // Timeline
                  _buildTimelineSection(context),
                  
                  // Our services
                  _buildServicesSection(context),
                  
                  // Team
                  _buildTeamSection(context),
                  
                  // Testimonials
                  _buildTestimonialsSection(context),
                  
                  // Contact & Support
                  _buildContactSection(context),
                  
                  // Footer
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo and Company Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.wifi,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Company Name and Tagline
          Center(
            child: Column(
              children: [
                Text(
                  'Truthy Systems',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Innovative WiFi Solutions for Everyone',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Quick stats
          if (!isSmallScreen)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(context, '3+', 'Years Experience'),
                _buildDivider(),
                _buildStatItem(context, '1000+', 'Happy Customers'),
                _buildDivider(),
                _buildStatItem(context, '99.9%', 'Uptime Guarantee'),
              ],
            )
          else
            Column(
              children: [
                _buildStatItem(context, '3+', 'Years Experience'),
                const SizedBox(height: 16),
                _buildStatItem(context, '1000+', 'Happy Customers'),
                const SizedBox(height: 16),
                _buildStatItem(context, '99.9%', 'Uptime Guarantee'),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Version pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Version 3.7.0',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Our Mission',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge,
              children: const [
                TextSpan(
                  text: 'Truthy Systems is on a mission to ',
                ),
                TextSpan(
                  text: 'bridge the digital divide ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: 'by providing reliable, high-speed WiFi solutions that are accessible to everyone. '
                      'We believe that internet access is essential in today\'s world, and we\'re committed to '
                      'making it available to all communities, regardless of their location or economic status.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Core Values',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildValueItem(
                    context, 
                    'Reliability', 
                    'We deliver consistent, dependable service that our customers can count on.',
                    Icons.verified,
                  ),
                  
                  _buildValueItem(
                    context, 
                    'Innovation', 
                    'We continuously explore new technologies and methods to improve our services.',
                    Icons.lightbulb_outline,
                  ),
                  
                  _buildValueItem(
                    context, 
                    'Community', 
                    'We build stronger connections by bringing people together through technology.',
                    Icons.people_outline,
                  ),
                  
                  _buildValueItem(
                    context, 
                    'Affordability', 
                    'We offer cost-effective solutions without compromising on quality.',
                    Icons.attach_money,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueItem(
    BuildContext context, 
    String title, 
    String description, 
    IconData icon, 
    {bool isLast = false}
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Our Journey',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          _buildTimelineItem(
            context,
            year: '2021',
            title: 'Foundation',
            description: 'Truthy Systems was founded with a vision to provide reliable WiFi solutions in Kampala.',
            icon: Icons.start,
            isFirst: true,
          ),
          
          _buildTimelineItem(
            context,
            year: '2022',
            title: 'Expansion',
            description: 'Expanded our services to multiple regions and introduced innovative subscription plans.',
            icon: Icons.trending_up,
          ),
          
          _buildTimelineItem(
            context,
            year: '2023',
            title: 'Technology Upgrade',
            description: 'Upgraded our infrastructure and launched the Truthy WiFi Manager application.',
            icon: Icons.upgrade,
          ),
          
          _buildTimelineItem(
            context,
            year: '2024',
            title: 'Community Focus',
            description: 'Implemented a referral program and introduced special rates for educational institutions.',
            icon: Icons.people,
          ),
          
          _buildTimelineItem(
            context,
            year: '2025',
            title: 'Looking Forward',
            description: 'Continuing to innovate with expanded coverage and improved service quality.',
            icon: Icons.flight_takeoff,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required String year,
    required String title,
    required String description,
    required IconData icon,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    year,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Our Services',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We provide comprehensive WiFi solutions tailored to meet diverse needs',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildServiceCard(
                context,
                title: 'Residential WiFi',
                description: 'High-speed internet for homes with flexible subscription plans.',
                icon: Icons.home,
              ),
              
              _buildServiceCard(
                context,
                title: 'Business Solutions',
                description: 'Reliable connectivity for businesses with dedicated support.',
                icon: Icons.business,
              ),
              
              _buildServiceCard(
                context,
                title: 'Subscription Management',
                description: 'Easy-to-use tools for managing customer subscriptions and payments.',
                icon: Icons.receipt_long,
              ),
              
              _buildServiceCard(
                context,
                title: 'Technical Support',
                description: '24/7 support for all your WiFi-related needs.',
                icon: Icons.support_agent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 900 ? (width - 80) / 4 : width > 600 ? (width - 64) / 2 : width - 48;
    
    return SizedBox(
      width: itemWidth,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 16),
              Text(
                'Learn More',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Our Team',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Meet the passionate individuals behind Truthy Systems',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildTeamMemberCard(
                context, 
                name: 'Alex Morgan',
                role: 'Founder & CEO',
                bio: 'Passionate about technology and making internet accessible to everyone.',
              ),
              
              _buildTeamMemberCard(
                context, 
                name: 'Sarah Johnson',
                role: 'CTO',
                bio: 'Brings 10+ years of experience in network engineering and infrastructure development.',
              ),
              
              _buildTeamMemberCard(
                context, 
                name: 'Michael Chen',
                role: 'Head of Customer Support',
                bio: 'Dedicated to ensuring our customers receive the best service possible.',
              ),
              
              _buildTeamMemberCard(
                context, 
                name: 'Rachel Kamau',
                role: 'Operations Manager',
                bio: 'Expert in streamlining processes and optimizing business operations.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberCard(
    BuildContext context, {
    required String name,
    required String role,
    required String bio,
  }) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 900 ? (width - 80) / 4 : width > 600 ? (width - 64) / 2 : width - 48;
    
    return SizedBox(
      width: itemWidth,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  name.substring(0, 1),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(context, Icons.email),
                  const SizedBox(width: 16),
                  _buildSocialIcon(context, Icons.link),
                  const SizedBox(width: 16),
                  _buildSocialIcon(context, Icons.phone),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(BuildContext context, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'What Our Customers Say',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildTestimonialCard(
                context,
                quote: 'Truthy Systems has transformed how I manage my WiFi subscriptions. The app is intuitive and the service is reliable.',
                author: 'James M.',
                role: 'Small Business Owner',
              ),
              
              _buildTestimonialCard(
                context,
                quote: 'The referral program is fantastic! I\'ve earned several free days and my friends are happy with the service too.',
                author: 'Lisa K.',
                role: 'Residential Customer',
              ),
              
              _buildTestimonialCard(
                context,
                quote: 'Customer support is exceptional. Any issues I\'ve had were resolved quickly and professionally.',
                author: 'Robert T.',
                role: 'Internet Café Owner',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(
    BuildContext context, {
    required String quote,
    required String author,
    required String role,
  }) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 900 ? (width - 80) / 3 : width > 600 ? (width - 64) / 2 : width - 48;
    
    return SizedBox(
      width: itemWidth,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote,
                size: 40,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                quote,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      author.substring(0, 1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          role,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Get In Touch',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Have questions or need assistance? We\'re here to help!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildContactMethod(
                context,
                icon: Icons.email_outlined,
                title: 'Email Us',
                detail: 'truthysys@proton.me',
                onTap: () {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'truthysys@proton.me',
                  );
                  launchUrl(emailLaunchUri);
                },
              ),
              
              _buildContactMethod(
                context,
                icon: Icons.phone_outlined,
                title: 'Call Us',
                detail: '+256-783-009649',
                onTap: () {
                  final Uri telLaunchUri = Uri(
                    scheme: 'tel',
                    path: '+256783009649',
                  );
                  launchUrl(telLaunchUri);
                },
              ),
              
              _buildContactMethod(
                context,
                icon: Icons.location_on_outlined,
                title: 'Visit Us',
                detail: 'Kampala, Uganda',
                onTap: () {
                  final Uri mapsLaunchUri = Uri.parse(
                    'https://maps.google.com/?q=Kampala,Uganda',
                  );
                  launchUrl(mapsLaunchUri);
                },
              ),
              
              _buildContactMethod(
                context,
                icon: Icons.support_outlined,
                title: 'Support Hours',
                detail: 'Mon-Fri: 8am-6pm (EAT)',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('24/7 emergency support is also available'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Call to action
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to get started?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join thousands of satisfied customers today!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Contact Sales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: 16,
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contact form coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactMethod(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 900 ? (width - 96) / 4 : width > 600 ? (width - 72) / 2 : width - 48;
    
    return SizedBox(
      width: itemWidth,
      child: Semantics(
        button: true,
        label: '$title: $detail',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Text(
                'Truthy Systems',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 20,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildFooterLink(context, 'Privacy Policy'),
              _buildFooterLink(context, 'Terms of Service'),
              _buildFooterLink(context, 'FAQ'),
              _buildFooterLink(context, 'Blog'),
              _buildFooterLink(context, 'Careers'),
              _buildFooterLink(context, 'Contact'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton(context, Icons.facebook),
              const SizedBox(width: 16),
              _buildSocialButton(context, Icons.whatshot),
              const SizedBox(width: 16),
              _buildSocialButton(context, Icons.telegram),
              const SizedBox(width: 16),
              _buildSocialButton(context, Icons.alternate_email),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '© ${DateTime.now().year} Truthy Systems. All rights reserved.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Kampala, Uganda',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String text) {
    return Semantics(
      button: true,
      label: text,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$text page coming soon!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, IconData icon) {
    return Semantics(
      button: true,
      label: 'Social media link',
      child: IconButton(
        icon: Icon(icon),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Social media links coming soon!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _shareApp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share via'),
            subtitle: const Text('Tell others about Truthy WiFi Manager'),
          ),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('Message'),
            onTap: () {
              Navigator.pop(context);
              Share.share(
                'Check out Truthy WiFi Manager for easy subscription management: https://truthysystems.com',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            onTap: () {
              Navigator.pop(context);
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                queryParameters: {
                  'subject': 'Check out Truthy WiFi Manager',
                  'body': 'I\'ve been using this great app for managing WiFi subscriptions: https://truthysystems.com',
                }
              );
              launchUrl(emailLaunchUri);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Link'),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(
                const ClipboardData(text: 'https://truthysystems.com'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  final Color color;
  
  BackgroundPatternPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    const spacing = 30.0;
    
    // Draw horizontal lines
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Draw vertical lines
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Draw diagonal lines
    for (var i = -size.height; i < size.width; i += spacing * 2) {
      canvas.drawLine(
        Offset(i, 0), 
        Offset(i + size.height, size.height), 
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Share {
  static void share(String text) {
    // This is a placeholder method since the actual Share.share method 
    // would require importing the share_plus package
    print('Sharing: $text');
    // In a real app, would call Share.share from share_plus package
  }
}