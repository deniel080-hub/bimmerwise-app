import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';

class ServiceSelectionPage extends StatefulWidget {
  final String category;

  const ServiceSelectionPage({
    super.key,
    required this.category,
  });

  @override
  State<ServiceSelectionPage> createState() => _ServiceSelectionPageState();
}

class _ServiceSelectionPageState extends State<ServiceSelectionPage> {
  String? _loggedInUserId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      setState(() => _loggedInUserId = currentUser?.uid);
    } catch (e) {
      debugPrint('Error checking login status: $e');
    } finally {
    }
  }

  void _handleServiceSelection(String serviceTitle, bool isSpecialBooking) {
    if (serviceTitle == 'BMW XHP Stage 1/2/3 Gearbox Remap') {
      // Special booking flow for BMW XHP Gearbox Remap
      context.push('/xhp-remap-booking${_loggedInUserId != null ? '?userId=$_loggedInUserId' : ''}');
    } else if (serviceTitle == 'Wireless Apple Carplay Activation') {
      // Special booking flow for Wireless Apple Carplay
      context.push('/carplay-booking${_loggedInUserId != null ? '?userId=$_loggedInUserId' : ''}');
    } else if (serviceTitle == 'Gearbox Service') {
      // Special booking flow for Gearbox Service
      context.push('/gearbox-booking${_loggedInUserId != null ? '?userId=$_loggedInUserId' : ''}');
    } else if (serviceTitle == 'Regular Service') {
      // Special booking flow for Regular Service
      context.push('/regular-service-booking${_loggedInUserId != null ? '?userId=$_loggedInUserId' : ''}');
    } else {
      // Regular booking flow - guests can book directly
      if (_loggedInUserId != null) {
        debugPrint('Navigating to registered booking with userId: $_loggedInUserId');
        context.push('/registered-booking?userId=$_loggedInUserId&service=$serviceTitle&category=${widget.category}');
      } else {
        context.push('/guest-booking?service=$serviceTitle&category=${widget.category}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _getServicesForCategory(widget.category);
    final title = _getCategoryTitle(widget.category);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001E50),
              Color(0xFF1B4470),
              Color(0xFF2B6A9E),
              Color(0xFF8B3A8B),
              Color(0xFFB93B6C),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: AppSpacing.paddingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Select a Service',
                          style: context.textStyles.headlineSmall?.semiBold.withColor(Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Choose from our comprehensive range of BMW services',
                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                        ),
                        const SizedBox(height: AppSpacing.xl),
              ...List.generate(services.length, (index) {
                final service = services[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < services.length - 1 ? AppSpacing.md : 0,
                  ),
                  child: ServiceDetailCard(
                    title: service['title'],
                    description: service['description'],
                    features: service['features'],
                    price: service['price'],
                    priceNote: service['priceNote'],
                    icon: service['icon'],
                    imagePath: service['title'] == 'Wireless Apple Carplay Activation' 
                        ? 'assets/images/640.png' 
                        : service['title'] == 'Gearbox Service'
                        ? 'assets/images/gearbox.jpg'
                        : null,
                    onTap: () => _handleServiceSelection(
                      service['title'],
                      service['isSpecialBooking'] ?? false,
                    ),
                  ),
                );
              }),
                        const SizedBox(height: AppSpacing.xxl),
                        Container(
                          padding: AppSpacing.paddingLg,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Need Help Choosing?',
                                style: context.textStyles.titleMedium?.semiBold.withColor(Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Contact us for personalized recommendations based on your BMW model and needs.',
                                style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
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

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'bookin':
        return 'High Voltage Services';
      case 'service':
        return 'Car Service';
      case 'coding':
        return 'Coding Services';
      case 'healthcheck':
        return 'Vehicle Health Check';
      default:
        return 'Services';
    }
  }

  List<Map<String, dynamic>> _getServicesForCategory(String category) {
    switch (category) {
      case 'bookin':
        return [
          {
            'title': 'Regular Service',
            'description': 'Comprehensive maintenance package to keep your BMW in top condition',
            'features': [
              'Oil filter replacement',
              'Air filter replacement',
              'Fresh engine oil',
              'Complete vehicle inspection',
              'Basic diagnostic scan',
            ],
            'price': '€250',
            'priceNote': 'Starting from €250 (varies by model)',
            'icon': Icons.build,
          },
          {
            'title': 'Regular Maintenance',
            'description': 'Extended service package with additional checks and replacements',
            'features': [
              'All Regular Service items',
              'Brake fluid inspection',
              'Coolant level check',
              'Battery health check',
              'Tire pressure adjustment',
              'Detailed diagnostic report',
            ],
            'price': '€450',
            'priceNote': 'Starting from €450 (varies by model)',
            'icon': Icons.format_list_bulleted,
          },
          {
            'title': 'Major Service',
            'description': 'Complete overhaul service for optimal performance and longevity',
            'features': [
              'All Comprehensive Service items',
              'Spark plug replacement',
              'Transmission fluid check',
              'Suspension inspection',
              'Brake pad inspection',
              'Complete computer diagnostic',
              'Road test',
            ],
            'price': '€750',
            'priceNote': 'Starting from €750 (varies by model)',
            'icon': Icons.build_circle,
          },
        ];
      case 'service':
        return [
          {
            'title': 'Regular Service',
            'description': 'Regular maintenance package to keep your BMW running smoothly. Price varies based on fuel type and engine size.',
            'features': [
              'Oil & Oil filter replacement',
              'Air filter replacement',
              'Regular vehicle inspection',
              'Basic diagnostic scan',
              'Topping up washer fluid & coolant',
              'Registered Official BMW Garage',
              'Original BMW parts',
            ],
            'price': '€300-€475',
            'priceNote': 'Price depends on fuel type and engine size',
            'icon': Icons.car_repair,
            'isSpecialBooking': true,
          },
          {
            'title': 'Gearbox Service',
            'description': 'Using GENUINE ZF TRANSMISSION OIL PAN Filter Gasket',
            'features': [
              'Petrol/Diesel - €625',
              'Plug In Hybrid - €700',
              'Genuine ZF parts only',
              'Transmission oil replacement',
              'Filter and gasket replacement',
            ],
            'price': '€625-€700',
            'priceNote': 'Price depends on engine type',
            'icon': Icons.settings,
            'isSpecialBooking': true,
          },
          {
            'title': 'Region Change Japan to EU',
            'description': 'Complete region conversion from Japanese to European specifications',
            'features': [
              'ECU region modification',
              'Navigation system update',
              'Language conversion',
              'Speedometer recalibration',
              'Compliance certification',
            ],
            'price': '€500',
            'priceNote': 'Fixed price',
            'icon': Icons.public,
          },
          {
            'title': 'Main/Head Unit Inspection',
            'description': 'Comprehensive diagnostics and coding for your BMW head unit',
            'features': [
              'Complete system diagnostic',
              'Software version check',
              'Error code analysis',
              'Performance optimization',
              'Feature activation check',
            ],
            'price': '€150',
            'priceNote': 'Inspection only',
            'icon': Icons.dashboard,
          },
          {
            'title': 'Main/Head Unit Upgrade',
            'description': 'Software and feature upgrades for enhanced functionality',
            'features': [
              'Software update to latest version',
              'Feature activation',
              'Performance tuning',
              'System optimization',
              'Post-upgrade testing',
            ],
            'price': '€300',
            'priceNote': 'Including coding',
            'icon': Icons.upgrade,
          },
          {
            'title': 'Brake Fluid Service',
            'description': 'Complete brake fluid replacement to ensure optimal braking performance',
            'features': [
              'Complete brake fluid flush',
              'High-quality DOT 4 brake fluid',
              'Brake system inspection',
              'Bleeding of all brake lines',
              'Brake performance test',
              'Recommended every 2 years',
            ],
            'price': '€150',
            'priceNote': 'Standard service',
            'icon': Icons.oil_barrel,
          },
        ];
      case 'coding':
        return [
          {
            'title': 'BMW XHP Stage 1/2/3 Gearbox Remap',
            'description': 'Perfect for: Most BMW & MINI models (Petrol & Diesel). A full custom tune for owners who want maximum safe power gains beyond what OEM software can offer.',
            'features': [
              'Custom tune for maximum safe power',
              'Compatible with most BMW & MINI models',
              'Available for Petrol & Diesel',
              'Professional installation',
              'Performance optimization',
            ],
            'price': 'From €500',
            'priceNote': 'Price depends on your gearbox model',
            'icon': Icons.speed,
            'isSpecialBooking': true,
          },
          {
            'title': 'Wireless Apple Carplay Activation',
            'description': 'Enable wireless Apple CarPlay in your BMW',
            'features': [
              'NBT EVO ID4 - €285',
              'NBT EVO ID5/6 - €170 (some models €285)',
              'ENAEVO - €285',
              'Professional installation',
              'Full system integration',
            ],
            'price': '€170-€285',
            'priceNote': 'Price depends on your system type',
            'icon': Icons.phone_iphone,
            'isSpecialBooking': true,
          },
          {
            'title': 'Basic Coding',
            'description': 'Simple feature activation and basic modifications',
            'features': [
              'Single feature activation',
              'Basic module coding',
              'Configuration backup',
              'Testing and verification',
            ],
            'price': '€100',
            'priceNote': 'Per feature',
            'icon': Icons.code,
          },
          {
            'title': 'Advanced Coding',
            'description': 'Complex coding procedures and multiple feature activation',
            'features': [
              'Multiple feature activation',
              'Advanced module programming',
              'Custom configurations',
              'Performance optimization',
              'Complete system backup',
            ],
            'price': '€250',
            'priceNote': 'Up to 5 features',
            'icon': Icons.settings_applications,
          },
          {
            'title': 'Complete Coding Package',
            'description': 'Full vehicle coding with all available features',
            'features': [
              'All available feature activation',
              'Complete vehicle programming',
              'Navigation updates',
              'Performance tuning',
              'Lifetime support',
            ],
            'price': '€500',
            'priceNote': 'Complete package',
            'icon': Icons.auto_awesome,
          },
        ];
      case 'healthcheck':
        return [
          {
            'title': 'Standard Pre-Purchase Inspection',
            'description': 'Comprehensive inspection before buying a BMW with up to 80 point checks',
            'features': [
              'Points checked up to 80',
              'Test drive up to 5 kms',
              'Inspection report',
              'Diagnostic report',
              'History check inc Finance UK/IE',
              'BMW online service records',
              'Duration: 1.5 hours',
              'BMW service history provided in Email/Printed version only if the purchase successful',
            ],
            'price': '€200',
            'priceNote': 'Complete inspection',
            'icon': Icons.search,
          },
          {
            'title': 'Premium Pre-Purchase Inspection',
            'description': 'Extended inspection with up to 100 point checks including High Voltage Battery check',
            'features': [
              'Points checked up to 100',
              'Test drive up to 10 kms',
              'Inspection report',
              'Diagnostic report',
              'History check inc Finance UK/IE',
              'History check Japan',
              'BMW online service record',
              'High Voltage Battery check',
              'Duration: 3 hours (Japan history: up to 3 working days)',
              'BMW service history provided in Email/Printed version only if the purchase successful',
            ],
            'price': '€325',
            'priceNote': 'Premium inspection',
            'icon': Icons.verified,
          },
          {
            'title': 'Vehicle Health Check',
            'description': 'Regular health assessment for your BMW',
            'features': [
              'Computer diagnostic scan',
              'Fluid level checks',
              'Brake system inspection',
              'Tire condition assessment',
              'Battery health test',
              'Health report with recommendations',
            ],
            'price': '€100',
            'priceNote': 'Standard check',
            'icon': Icons.health_and_safety,
          },
          {
            'title': 'Extended Diagnostic',
            'description': 'In-depth diagnostic analysis for complex issues',
            'features': [
              'Advanced computer diagnostics',
              'Module-by-module analysis',
              'Error code interpretation',
              'Root cause analysis',
              'Repair recommendations',
              'Detailed technical report',
            ],
            'price': '€250',
            'priceNote': 'Comprehensive diagnostic',
            'icon': Icons.biotech,
          },
        ];
      default:
        return [];
    }
  }
}

class ServiceDetailCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> features;
  final String price;
  final String priceNote;
  final IconData icon;
  final String? imagePath;
  final VoidCallback onTap;

  const ServiceDetailCard({
    super.key,
    required this.title,
    required this.description,
    required this.features,
    required this.price,
    required this.priceNote,
    required this.icon,
    this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.asset(
                            imagePath!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                icon,
                                color: Colors.white,
                                size: 28,
                              );
                            },
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        price,
                        style: context.textStyles.headlineSmall?.bold.withColor(Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Includes:',
                  style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          feature,
                          style: context.textStyles.bodyMedium?.withColor(Colors.white),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          priceNote,
                          style: context.textStyles.bodySmall?.withColor(Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF001E50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'Select This Service',
                      style: context.textStyles.titleMedium?.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
