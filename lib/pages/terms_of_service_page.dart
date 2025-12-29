import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Terms of Service page displaying service agreement and usage terms
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              'BIMMERWISE Terms of Service',
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
              '1. Acceptance of Terms',
              'By accessing and using the BIMMERWISE mobile application and services, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use our services.',
            ),
            
            _buildSection(
              context,
              '2. Description of Service',
              'BIMMERWISE provides a platform for BMW vehicle owners to:\n\n'
              '• Book and manage vehicle service appointments\n'
              '• Track vehicle service history and maintenance records\n'
              '• Purchase automotive parts and accessories\n'
              '• Receive service notifications and reminders\n'
              '• Communicate with our service center',
            ),
            
            _buildSection(
              context,
              '3. User Accounts',
              'To use our services, you must:\n\n'
              '• Provide accurate and complete registration information\n'
              '• Maintain the security of your account credentials\n'
              '• Be at least 18 years of age\n'
              '• Notify us immediately of any unauthorized use of your account\n\n'
              'You are responsible for all activities that occur under your account.',
            ),
            
            _buildSection(
              context,
              '4. Service Bookings',
              '• All service bookings are subject to availability\n'
              '• We reserve the right to refuse or cancel bookings\n'
              '• Cancellation policies apply as per our service agreement\n'
              '• Prices and service offerings are subject to change\n'
              '• Additional charges may apply for parts and services not included in the initial quote',
            ),
            
            _buildSection(
              context,
              '5. Vehicle Information',
              'You agree to:\n\n'
              '• Provide accurate vehicle information (VIN, registration, mileage)\n'
              '• Keep your vehicle information up to date\n'
              '• Ensure that you have the right to register and service the vehicles listed in your account\n'
              '• Not use the service for vehicles you do not own or have authorization to service',
            ),
            
            _buildSection(
              context,
              '6. Payments and Purchases',
              '• All prices are in [Your Currency] unless otherwise stated\n'
              '• Payment is required at the time of service completion or part purchase\n'
              '• We accept payment methods as indicated in the app\n'
              '• Refunds are subject to our refund policy\n'
              '• You are responsible for any applicable taxes',
            ),
            
            _buildSection(
              context,
              '7. Intellectual Property',
              'All content, features, and functionality of the BIMMERWISE app, including but not limited to text, graphics, logos, and software, are owned by BIMMERWISE and are protected by copyright, trademark, and other intellectual property laws.',
            ),
            
            _buildSection(
              context,
              '8. User Conduct',
              'You agree not to:\n\n'
              '• Use the service for any unlawful purpose\n'
              '• Attempt to gain unauthorized access to our systems\n'
              '• Interfere with or disrupt the service\n'
              '• Upload malicious code or harmful content\n'
              '• Impersonate any person or entity\n'
              '• Violate any applicable laws or regulations',
            ),
            
            _buildSection(
              context,
              '9. Limitation of Liability',
              'BIMMERWISE shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the service. Our total liability shall not exceed the amount you paid for services in the past 12 months.',
            ),
            
            _buildSection(
              context,
              '10. Warranty Disclaimer',
              'The service is provided "as is" and "as available" without warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted, secure, or error-free.',
            ),
            
            _buildSection(
              context,
              '11. Service Modifications',
              'We reserve the right to modify or discontinue the service at any time, with or without notice. We shall not be liable to you or any third party for any modification, suspension, or discontinuance of the service.',
            ),
            
            _buildSection(
              context,
              '12. Termination',
              'We may terminate or suspend your account and access to the service immediately, without prior notice, for any reason, including breach of these Terms. Upon termination, your right to use the service will immediately cease.',
            ),
            
            _buildSection(
              context,
              '13. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law provisions.',
            ),
            
            _buildSection(
              context,
              '14. Changes to Terms',
              'We reserve the right to modify these terms at any time. We will notify users of any material changes. Your continued use of the service after such modifications constitutes acceptance of the updated terms.',
            ),
            
            _buildSection(
              context,
              '15. Contact Information',
              'For questions about these Terms of Service, please contact us at:\n\n'
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
