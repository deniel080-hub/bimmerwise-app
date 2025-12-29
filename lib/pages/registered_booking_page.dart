import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';

class RegisteredBookingPage extends StatefulWidget {
  final String userId;
  final String serviceTitle;
  final String serviceCategory;

  const RegisteredBookingPage({
    super.key,
    required this.userId,
    required this.serviceTitle,
    required this.serviceCategory,
  });

  @override
  State<RegisteredBookingPage> createState() => _RegisteredBookingPageState();
}

class _RegisteredBookingPageState extends State<RegisteredBookingPage> {
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  String _userName = '';
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('Loading user data for userId: ${widget.userId}');
      final userService = UserService();
      final vehicleService = VehicleService();

      final user = await userService.getUserById(widget.userId);
      final vehicles = await vehicleService.getVehiclesByUserId(widget.userId);
      debugPrint('Found ${vehicles.length} vehicles for user');

      setState(() {
        _userName = user?.name ?? '';
        _vehicles = vehicles.map((v) => {
          'id': v.id,
          'display': '${v.year} ${v.model} (${v.licensePlate})',
          'model': v.model,
          'year': v.year,
        }).toList();
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
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
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a vehicle'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

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
      final serviceRecordService = ServiceRecordService();

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final description = _notesController.text.trim().isNotEmpty
          ? '${widget.serviceTitle} - ${_notesController.text.trim()}'
          : widget.serviceTitle;

      final serviceRecord = ServiceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: _selectedVehicleId!,
        userId: widget.userId,
        serviceType: widget.serviceTitle,
        description: description,
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
        final userService = UserService();
        final user = await userService.getUserById(widget.userId);
        if (user != null) {
          final vehicle = await VehicleService().getVehicleById(_selectedVehicleId!);
          if (vehicle != null) {
            await NotificationService().sendBookingCreatedNotificationToAllAdmins(
              bookingId: serviceRecord.id,
              customerName: user.name,
              customerEmail: user.email,
              serviceName: widget.serviceTitle,
              vehicleInfo: vehicle.model,
              bookingDate: scheduledDateTime,
            );
          }
        }
      } catch (notificationError) {
        // Log but don't fail the booking if notification fails
        debugPrint('⚠️ Failed to send admin notification: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Booking created successfully! You will be notified when service is complete.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      debugPrint('❌ Error creating booking: $e');
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
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
                                  'Welcome, ${_userName.isNotEmpty ? _userName : 'Guest'}',
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
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Welcome, $_userName',
                                  style: context.textStyles.titleLarge?.semiBold,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(
                                  Icons.build,
                                  color: Theme.of(context).colorScheme.secondary,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Service: ${widget.serviceTitle}',
                                    style: context.textStyles.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Select Your Vehicle',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_vehicles.isEmpty)
                      Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No vehicles found',
                              style: context.textStyles.titleMedium?.semiBold,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Please add a vehicle to your account first',
                              style: context.textStyles.bodyMedium?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ..._vehicles.map((vehicle) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedVehicleId = vehicle['id']),
                          child: Container(
                            padding: AppSpacing.paddingLg,
                            decoration: BoxDecoration(
                              color: _selectedVehicleId == vehicle['id']
                                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: _selectedVehicleId == vehicle['id']
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                width: _selectedVehicleId == vehicle['id'] ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.directions_car,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    vehicle['display'],
                                    style: context.textStyles.titleMedium?.semiBold,
                                  ),
                                ),
                                if (_selectedVehicleId == vehicle['id'])
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 28,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )),
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
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Additional Notes',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add any specific requests or information...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: AppSpacing.paddingMd,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: 20,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'You will receive a notification when your service is completed',
                              style: context.textStyles.bodySmall?.withColor(
                                Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: _vehicles.isEmpty ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Confirm Booking',
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
    );
  }
}
