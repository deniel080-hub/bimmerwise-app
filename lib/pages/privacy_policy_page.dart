import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Privacy Policy page displaying data collection and usage policies
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BIMMERWISE Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${DateTime.now().year}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              context,
              '1. Information We Collect',
              'We collect information that you provide directly to us, including:\n\n'
              '• Personal Information: Name, email address, phone number\n'
              '• Vehicle Information: VIN number, registration/license plate, make, model, year, mileage\n'
              '• Service Records: Service history, maintenance records, uploaded images\n'
              '• Account Information: Login credentials, preferences',
            ),
            
            _buildSection(
              context,
              '2. How We Use Your Information',
              'We use the information we collect to:\n\n'
              '• Provide, maintain, and improve our services\n'
              '• Process your service bookings and appointments\n'
              '• Send you service reminders and notifications\n'
              '• Maintain your vehicle service history\n'
              '• Communicate with you about your account and services\n'
              '• Respond to your requests and provide customer support',
            ),
            
            _buildSection(
              context,
              '3. Information Sharing and Disclosure',
              'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n'
              '• With your consent\n'
              '• To comply with legal obligations\n'
              '• To protect our rights and prevent fraud\n'
              '• With service providers who assist in our operations (under strict confidentiality agreements)',
            ),
            
            _buildSection(
              context,
              '4. Data Security',
              'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
            ),
            
            _buildSection(
              context,
              '5. Data Retention',
              'We retain your information for as long as your account is active or as needed to provide you services. You may request deletion of your account and data at any time by contacting us.',
            ),
            
            _buildSection(
              context,
              '6. Your Rights',
              'You have the right to:\n\n'
              '• Access your personal information\n'
              '• Correct inaccurate information\n'
              '• Request deletion of your information\n'
              '• Opt-out of marketing communications\n'
              '• Export your data',
            ),
            
            _buildSection(
              context,
              '7. Children\'s Privacy',
              'Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.',
            ),
            
            _buildSection(
              context,
              '8. Changes to This Policy',
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Last Updated" date.',
            ),
            
            _buildSection(
              context,
              '9. Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\n'
              'Email: support@bimmerwise.com\n'
              'Phone: [Your Contact Number]\n'
              'Address: [Your Business Address]',
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
