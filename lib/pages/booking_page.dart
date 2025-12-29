import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class BookingPage extends StatefulWidget {
  final String customerId;

  const BookingPage({
    super.key,
    required this.customerId,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final UserService _userService = UserService();
  final VehicleService _vehicleService = VehicleService();
  final ServiceRecordService _serviceRecordService = ServiceRecordService();

  User? _user;
  Vehicle? _vehicle;
  bool _isLoading = true;

  String? _selectedService;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _serviceOptions = [
    {
      'title': 'Regular Servicing',
      'description': 'Oil change, oil filter, air filter, comprehensive inspection',
      'icon': Icons.build,
      'estimatedCost': 450.00,
    },
    {
      'title': 'Diagnostic',
      'description': 'Full diagnostic scan and error code analysis',
      'icon': Icons.computer,
      'estimatedCost': 150.00,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = await _userService.getUserById(widget.customerId);
    Vehicle? vehicle;

    if (user != null) {
      final vehicles = await _vehicleService.getVehiclesByUserId(user.id);
      if (vehicles.isNotEmpty) {
        vehicle = vehicles.first;
      }
    }

    setState(() {
      _user = user;
      _vehicle = vehicle;
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year, now.month + 3, now.day);
    
    DateTime initialDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service')),
      );
      return;
    }

    if (_vehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vehicle found for this customer')),
      );
      return;
    }

    try {
      final selectedServiceData = _serviceOptions.firstWhere(
        (s) => s['title'] == _selectedService,
      );

      final record = ServiceRecord(
        id: 'sr_${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: _vehicle!.id,
        userId: widget.customerId,
        serviceType: _selectedService!,
        description: _notesController.text.isEmpty
            ? selectedServiceData['description']
            : _notesController.text,
        serviceDate: _selectedDate,
        cost: selectedServiceData['estimatedCost'],
        status: 'Scheduled',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _serviceRecordService.addRecord(record);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Book Service',
          style: context.textStyles.titleLarge?.semiBold,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user!.name,
                            style: context.textStyles.titleMedium?.semiBold,
                          ),
                          if (_vehicle != null)
                            Text(
                              '${_vehicle!.year} ${_vehicle!.model}',
                              style: context.textStyles.bodySmall?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Select Service',
                style: context.textStyles.titleLarge?.semiBold,
              ),
              const SizedBox(height: AppSpacing.md),
              ...List.generate(_serviceOptions.length, (index) {
                final service = _serviceOptions[index];
                final isSelected = _selectedService == service['title'];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _serviceOptions.length - 1 ? AppSpacing.md : 0,
                  ),
                  child: ServiceOptionCard(
                    title: service['title'],
                    description: service['description'],
                    icon: service['icon'],
                    estimatedCost: service['estimatedCost'],
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedService = service['title']),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Select Date',
                style: context.textStyles.titleLarge?.semiBold,
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _selectDate,
                style: ElevatedButton.styleFrom(
                  padding: AppSpacing.paddingLg,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appointment Date',
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(_selectedDate),
                            style: context.textStyles.bodyLarge?.medium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Additional Notes (Optional)',
                style: context.textStyles.titleLarge?.semiBold,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Any specific concerns or requests...',
                  hintStyle: context.textStyles.bodyMedium?.withColor(
                    Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Confirm Booking',
                      style: context.textStyles.titleMedium?.semiBold.withColor(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final double estimatedCost;
  final bool isSelected;
  final VoidCallback onTap;

  const ServiceOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.estimatedCost,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
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
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Est. \$${estimatedCost.toStringAsFixed(2)}',
                    style: context.textStyles.bodyMedium?.semiBold.withColor(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
