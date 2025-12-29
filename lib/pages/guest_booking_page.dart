import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';

class GuestBookingPage extends StatefulWidget {
  final String serviceTitle;
  final String serviceCategory;

  const GuestBookingPage({
    super.key,
    required this.serviceTitle,
    required this.serviceCategory,
  });

  @override
  State<GuestBookingPage> createState() => _GuestBookingPageState();
}

class _GuestBookingPageState extends State<GuestBookingPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Customer information
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Vehicle information
  final _vinController = TextEditingController();
  final _registrationController = TextEditingController();
  final _makeController = TextEditingController(text: 'BMW');
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vinController.dispose();
    _registrationController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool _isValidBookingTime(DateTime date, TimeOfDay time) {
    final weekday = date.weekday;
    final hour = time.hour;
    final minute = time.minute;
    final totalMinutes = hour * 60 + minute;
    
    // Monday to Friday: 9:00 AM to 6:00 PM
    if (weekday >= 1 && weekday <= 5) {
      return totalMinutes >= 9 * 60 && totalMinutes < 18 * 60;
    }
    // Saturday: 9:00 AM to 2:00 PM
    else if (weekday == 6) {
      return totalMinutes >= 9 * 60 && totalMinutes < 14 * 60;
    }
    // Sunday: Not available
    return false;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year + 1, now.month, now.day);
    
    DateTime initialDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
    
    // If initialDate is Sunday, move to Monday to match selectableDayPredicate
    if (initialDate.weekday == 7) {
      initialDate = initialDate.add(const Duration(days: 1));
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (DateTime date) => date.weekday != 7,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate booking time
    if (!_isValidBookingTime(_selectedDate, _selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Booking is only available:\nMonday-Friday: 9:00 AM - 6:00 PM\nSaturday: 9:00 AM - 2:00 PM',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vehicleService = VehicleService();
      final serviceRecordService = ServiceRecordService();

      // Create guest user (no Firebase Auth account for guests)
      // For guests, we directly create the user document in Firestore
      final userId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final user = User(
        id: userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Note: Guest users are stored in Firestore without Firebase Auth
      // This requires special security rules for guest access
      await FirebaseFirestore.instance.collection('users').doc(userId).set(user.toJson());

      // Create vehicle
      final vehicle = Vehicle(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.id,
        model: '${_makeController.text.trim()} ${_modelController.text.trim()}',
        year: _yearController.text.trim(),
        vin: _vinController.text.trim(),
        licensePlate: _registrationController.text.trim(),
        color: 'Not specified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await vehicleService.addVehicle(vehicle);

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Create service record
      final serviceRecord = ServiceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: vehicle.id,
        serviceType: widget.serviceTitle,
        description: 'Guest booking - ${widget.serviceCategory}',
        serviceDate: scheduledDateTime,
        cost: 0.0,
        status: 'Booking In Progress',
        progress: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      debugPrint('🔧 Creating service record: ${serviceRecord.id}');
      await serviceRecordService.addRecord(serviceRecord);
      debugPrint('✅ Service record created successfully');

      // Send notification to ALL admin users (non-blocking)
      try {
        await NotificationService().sendBookingCreatedNotificationToAllAdmins(
          bookingId: serviceRecord.id,
          customerName: _nameController.text.trim(),
          customerEmail: _emailController.text.trim(),
          serviceName: widget.serviceTitle,
          vehicleInfo: '${_modelController.text.trim()} (${_yearController.text.trim()})',
          bookingDate: scheduledDateTime,
        );
      } catch (notificationError) {
        debugPrint('⚠️ Failed to send admin notification: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Guest Booking',
          style: context.textStyles.titleLarge?.semiBold,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.serviceTitle == 'Standard Pre-Purchase Inspection' || widget.serviceTitle == 'Premium Pre-Purchase Inspection')
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Icon(
                              widget.serviceTitle == 'Premium Pre-Purchase Inspection' ? Icons.verified : Icons.search,
                              size: 70,
                              color: Colors.white,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              widget.serviceTitle,
                              style: context.textStyles.headlineSmall?.bold.withColor(Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Welcome, Guest',
                              style: context.textStyles.titleMedium?.semiBold.withColor(Colors.white.withValues(alpha: 0.95)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Why Pre-Purchase Inspection?',
                                    style: context.textStyles.titleSmall?.bold.withColor(Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'A thorough pre-purchase inspection can save you thousands of euros by identifying potential issues before you buy. Our comprehensive checks ensure you make an informed decision and avoid costly surprises.',
                                    style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.9)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.serviceTitle == 'Premium Pre-Purchase Inspection')
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.black87,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MOST POPULAR',
                                    style: context.textStyles.bodySmall?.bold.withColor(Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Service: ${widget.serviceTitle}',
                            style: context.textStyles.titleSmall?.semiBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Customer Information',
                  style: context.textStyles.titleLarge?.semiBold,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Vehicle Information',
                        style: context.textStyles.titleLarge?.semiBold,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _makeController,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Make',
                    hintText: 'e.g., BMW, Mercedes',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle make';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Model',
                    hintText: 'e.g., X5, E-Class',
                    prefixIcon: const Icon(Icons.car_repair),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle model';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Year',
                    hintText: 'e.g., 2020',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle year';
                    }
                    final year = int.tryParse(value);
                    if (year == null || year < 1990 || year > DateTime.now().year + 1) {
                      return 'Please enter a valid year (1990-${DateTime.now().year + 1})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _vinController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 7,
                  decoration: InputDecoration(
                    labelText: 'VIN Number (Last 7 Characters)',
                    hintText: 'e.g., A123456',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter VIN number';
                    }
                    if (value.trim().length != 7) {
                      return 'VIN must be exactly 7 characters';
                    }
                    if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(value.trim())) {
                      return 'VIN must contain only letters and numbers';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _registrationController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Registration/License Plate',
                    hintText: 'e.g., ABC-1234',
                    prefixIcon: const Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter registration number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Schedule Appointment',
                  style: context.textStyles.titleLarge?.semiBold,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectDate,
                        icon: Icon(Icons.calendar_today, size: 20),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Date', style: context.textStyles.bodySmall),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: context.textStyles.titleSmall?.semiBold,
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: AppSpacing.paddingMd,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectTime,
                        icon: Icon(Icons.access_time, size: 20),
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Time', style: context.textStyles.bodySmall),
                            Text(
                              _selectedTime.format(context),
                              style: context.textStyles.titleSmall?.semiBold,
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: AppSpacing.paddingMd,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Submit Booking',
                          style: context.textStyles.titleMedium?.semiBold.withColor(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }
}
