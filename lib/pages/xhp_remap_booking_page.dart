import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';

class XhpRemapBookingPage extends StatefulWidget {
  final String userId;

  const XhpRemapBookingPage({
    super.key,
    required this.userId,
  });

  @override
  State<XhpRemapBookingPage> createState() => _XhpRemapBookingPageState();
}

class _XhpRemapBookingPageState extends State<XhpRemapBookingPage> {
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  String _userName = '';
  final _vinController = TextEditingController();
  final _registrationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isWhatIsXHPExpanded = false;
  bool _isOfficialDealerExpanded = false;
  bool _isKeyFeaturesExpanded = false;
  bool _isInstallationSupportExpanded = false;
  bool _isCompatibilityExpanded = false;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  // Guest vehicle information
  final _guestMakeController = TextEditingController(text: 'BMW');
  final _guestModelController = TextEditingController();
  final _guestYearController = TextEditingController();
  final _guestRegistrationController = TextEditingController();
  
  String? _selectedGearboxModel;
  String? _selectedPaymentMethod;
  
  final List<String> _gearboxModels = [
    '6-Speed Automatic',
    '7-Speed DCT',
    '8-Speed F Automatic',
    '8-Speed (G series/Supra)',
  ];

  final double _basePrice = 500.0;

  @override
  void dispose() {
    _vinController.dispose();
    _registrationController.dispose();
    _notesController.dispose();
    _guestMakeController.dispose();
    _guestModelController.dispose();
    _guestYearController.dispose();
    _guestRegistrationController.dispose();
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
          'fuelType': v.fuelType,
          'vin': v.vin,
          'licensePlate': v.licensePlate,
        }).toList();
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
          // Auto-fill VIN from first vehicle (last 7 characters)
          final firstVehicleVin = _vehicles.first['vin'] as String?;
          if (firstVehicleVin != null && firstVehicleVin.length >= 7) {
            _vinController.text = firstVehicleVin.substring(firstVehicleVin.length - 7).toUpperCase();
          }
          // Auto-fill registration from first vehicle
          final firstVehicleReg = _vehicles.first['licensePlate'] as String?;
          if (firstVehicleReg != null && firstVehicleReg.isNotEmpty) {
            _registrationController.text = firstVehicleReg.toUpperCase();
          }
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

  bool _validateForm() {
    if (_vehicles.isEmpty) {
      // Validate guest vehicle information
      if (_guestMakeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter vehicle make'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
      if (_guestModelController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter vehicle model'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
      if (_guestYearController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter vehicle year'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
      final year = int.tryParse(_guestYearController.text);
      if (year == null || year < 1990 || year > DateTime.now().year + 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a valid year (1990-${DateTime.now().year + 1})'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
      if (_guestRegistrationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter registration number'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
    } else if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a vehicle'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    if (_selectedGearboxModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your gearbox model'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    final vin = _vinController.text.trim();
    if (vin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter VIN'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
    
    if (vin.length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('VIN must be exactly 7 characters'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
    
    if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(vin.toUpperCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('VIN must contain only letters and numbers'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a payment method'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
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
      return false;
    }

    return true;
  }

  Future<void> _submitBooking() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final serviceRecordService = ServiceRecordService();
      
      String vehicleId = _selectedVehicleId ?? '';
      
      // Create vehicle for guest user if no vehicles exist
      if (_vehicles.isEmpty) {
        final vehicleService = VehicleService();
        final userService = UserService();
        
        // Create guest user if needed
        final user = await userService.getUserById(widget.userId);
        if (user == null) {
          throw Exception('User not found');
        }
        
        // Create vehicle
        final vehicle = Vehicle(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: widget.userId,
          model: '${_guestMakeController.text.trim()} ${_guestModelController.text.trim()}',
          year: _guestYearController.text.trim(),
          vin: _vinController.text.trim(),
          licensePlate: _guestRegistrationController.text.trim(),
          color: 'Not specified',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await vehicleService.addVehicle(vehicle);
        vehicleId = vehicle.id;
      }

      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final description = 'BMW XHP Gearbox Remap - $_selectedGearboxModel\n'
          'VIN: ${_vinController.text.trim()}\n'
          'Registration: ${_registrationController.text.trim()}\n'
          'Payment: $_selectedPaymentMethod'
          '${_notesController.text.trim().isNotEmpty ? '\nNotes: ${_notesController.text.trim()}' : ''}';

      final serviceRecord = ServiceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: vehicleId,
        userId: widget.userId,
        serviceType: 'BMW XHP Gearbox Remap',
        description: description,
        serviceDate: scheduledDateTime,
        cost: _basePrice,
        status: 'Booking In Progress',
        progress: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      debugPrint('🔧 Creating service record: ${serviceRecord.id}');
      await serviceRecordService.addRecord(serviceRecord);
      debugPrint('✅ Service record created successfully');

      // Send notification to admin (non-blocking)
      try {
        final userService = UserService();
        final user = await userService.getUserById(widget.userId);
        if (user != null) {
          final vehicle = _vehicles.isNotEmpty 
              ? _vehicles.firstWhere((v) => v['id'] == vehicleId)
              : {'display': '${_guestMakeController.text} ${_guestModelController.text} (${_guestRegistrationController.text})'};
          await NotificationService().sendBookingCreatedNotificationToAllAdmins(
            bookingId: serviceRecord.id,
            customerName: user.name,
            customerEmail: user.email,
            serviceName: 'BMW XHP Gearbox Remap',
            vehicleInfo: vehicle['display'] as String,
            bookingDate: scheduledDateTime,
          );
        }
      } catch (notificationError) {
        debugPrint('⚠️ Failed to send admin notification: $notificationError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedPaymentMethod == 'Card'
                  ? 'Booking created! Payment of €${_basePrice.toStringAsFixed(0)} will be processed.'
                  : 'Booking created! Please bring €${_basePrice.toStringAsFixed(0)} in cash.'
            ),
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
                        'BMW XHP Gearbox Remap',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                        child: Padding(
                          padding: AppSpacing.paddingLg,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Service header with image
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
                                      Icons.speed,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'BMW XHP Gearbox Remap',
                                      style: context.textStyles.titleLarge?.bold.withColor(Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Perfect for: Most BMW & MINI models (Petrol & Diesel). A full custom tune for owners who want maximum safe power gains beyond what OEM software can offer.',
                                      style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Welcome, $_userName',
                                      style: context.textStyles.bodyMedium?.withColor(Colors.white60),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Vehicle selection or information
                              Text(
                                _vehicles.isEmpty ? 'Vehicle Information' : 'Select Your Vehicle',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (_vehicles.isEmpty)
                                // Guest vehicle information form
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _guestMakeController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Vehicle Make',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                        hintText: 'e.g., BMW, Mercedes',
                                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                        prefixIcon: const Icon(Icons.directions_car, color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: Colors.white, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextField(
                                      controller: _guestModelController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Vehicle Model',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                        hintText: 'e.g., X5, E-Class',
                                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                        prefixIcon: const Icon(Icons.car_repair, color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: Colors.white, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextField(
                                      controller: _guestYearController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Vehicle Year',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                        hintText: 'e.g., 2020',
                                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                        prefixIcon: const Icon(Icons.calendar_today, color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: Colors.white, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextField(
                                      controller: _guestRegistrationController,
                                      textCapitalization: TextCapitalization.characters,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'Registration/License Plate',
                                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                        hintText: 'e.g., ABC-1234',
                                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                        prefixIcon: const Icon(Icons.confirmation_number, color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          borderSide: const BorderSide(color: Colors.white, width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                // Existing vehicle selection
                                Column(
                                  children: _vehicles.map((vehicle) => Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedVehicleId = vehicle['id'];
                                          // Auto-fill VIN from selected vehicle
                                          final vehicleVin = vehicle['vin'] as String?;
                                          if (vehicleVin != null && vehicleVin.length >= 7) {
                                            _vinController.text = vehicleVin.substring(vehicleVin.length - 7).toUpperCase();
                                          }
                                          // Auto-fill registration from selected vehicle
                                          final vehicleReg = vehicle['licensePlate'] as String?;
                                          if (vehicleReg != null && vehicleReg.isNotEmpty) {
                                            _registrationController.text = vehicleReg.toUpperCase();
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: AppSpacing.paddingMd,
                                        decoration: BoxDecoration(
                                          color: _selectedVehicleId == vehicle['id']
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          border: Border.all(
                                            color: _selectedVehicleId == vehicle['id']
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.3),
                                            width: _selectedVehicleId == vehicle['id'] ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.directions_car,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Text(
                                                vehicle['display'],
                                                style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                                              ),
                                            ),
                                            if (_selectedVehicleId == vehicle['id'])
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Gearbox Model Selection
                              Text(
                                'Select Gearbox Model',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<String>(
                                value: _selectedGearboxModel,
                                dropdownColor: const Color(0xFF001E50),
                                decoration: InputDecoration(
                                  hintText: 'Choose gearbox model',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  prefixIcon: const Icon(Icons.settings, color: Colors.white),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                ),
                                style: const TextStyle(color: Colors.white),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                items: _gearboxModels.map((model) {
                                  return DropdownMenuItem<String>(
                                    value: model,
                                    child: Text(
                                      model,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedGearboxModel = value),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // VIN number input
                              Text(
                                'VIN Number (Last 7 Characters)',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _vinController,
                                maxLength: 7,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(color: Colors.white),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'e.g., A123456',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  helperText: 'Exactly 7 characters (letters and numbers)',
                                  helperStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  prefixIcon: const Icon(Icons.badge, color: Colors.white),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                  counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  counterText: '${_vinController.text.length}/7',
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              
                              // Registration Number Input (for guests only)
                              if (_vehicles.isEmpty) ...[
                                Text(
                                  'Registration Number',
                                  style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                TextField(
                                  controller: _registrationController,
                                  style: const TextStyle(color: Colors.white),
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Enter registration number',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                    prefixIcon: const Icon(Icons.confirmation_number, color: Colors.white),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      borderSide: const BorderSide(color: Colors.white, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              
                              // Payment method selection
                              Text(
                                'Payment Method',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedPaymentMethod = 'Cash'),
                                      child: Container(
                                        padding: AppSpacing.paddingMd,
                                        decoration: BoxDecoration(
                                          color: _selectedPaymentMethod == 'Cash'
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          border: Border.all(
                                            color: _selectedPaymentMethod == 'Cash'
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.3),
                                            width: _selectedPaymentMethod == 'Cash' ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.payments,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            const SizedBox(height: AppSpacing.xs),
                                            Text(
                                              'Cash',
                                              style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                                            ),
                                            if (_selectedPaymentMethod == 'Cash')
                                              const Padding(
                                                padding: EdgeInsets.only(top: AppSpacing.xs),
                                                child: Icon(
                                                  Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedPaymentMethod = 'Card'),
                                      child: Container(
                                        padding: AppSpacing.paddingMd,
                                        decoration: BoxDecoration(
                                          color: _selectedPaymentMethod == 'Card'
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          border: Border.all(
                                            color: _selectedPaymentMethod == 'Card'
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.3),
                                            width: _selectedPaymentMethod == 'Card' ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.credit_card,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                            const SizedBox(height: AppSpacing.xs),
                                            Text(
                                              'Card',
                                              style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                                            ),
                                            if (_selectedPaymentMethod == 'Card')
                                              const Padding(
                                                padding: EdgeInsets.only(top: AppSpacing.xs),
                                                child: Icon(
                                                  Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Schedule appointment
                              Text(
                                'Schedule Appointment',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectDate,
                                      icon: const Icon(Icons.calendar_today, size: 20, color: Colors.white),
                                      label: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Date',
                                            style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.7)),
                                          ),
                                          Text(
                                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                            style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                                          ),
                                        ],
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: AppSpacing.paddingMd,
                                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectTime,
                                      icon: const Icon(Icons.access_time, size: 20, color: Colors.white),
                                      label: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Time',
                                            style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.7)),
                                          ),
                                          Text(
                                            _selectedTime.format(context),
                                            style: context.textStyles.titleSmall?.semiBold.withColor(Colors.white),
                                          ),
                                        ],
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: AppSpacing.paddingMd,
                                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Description Section (expandable)
                              Text(
                                'Description',
                                style: context.textStyles.titleMedium?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              
                              // What Is XHP Gearbox Remap? (expandable)
                              InkWell(
                                onTap: () => setState(() => _isWhatIsXHPExpanded = !_isWhatIsXHPExpanded),
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'What Is XHP Gearbox Remap?',
                                              style: context.textStyles.bodyLarge?.semiBold.withColor(Colors.white),
                                            ),
                                          ),
                                          Icon(
                                            _isWhatIsXHPExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      if (_isWhatIsXHPExpanded) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Divider(color: Colors.white38),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'XHP is a performance software upgrade specifically designed for ZF automatic gearboxes found in most modern BMWs. Developed through extensive real-world testing and data logging, XHP optimizes shift points, torque limits, and shift speeds to deliver a dynamic yet refined driving experience.',
                                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              
                              // Official XHP Dealer (expandable)
                              InkWell(
                                onTap: () => setState(() => _isOfficialDealerExpanded = !_isOfficialDealerExpanded),
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '🛠️ Official XHP Dealer',
                                              style: context.textStyles.bodyLarge?.semiBold.withColor(Colors.white),
                                            ),
                                          ),
                                          Icon(
                                            _isOfficialDealerExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      if (_isOfficialDealerExpanded) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Divider(color: Colors.white38),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'At BimmerWise, we are proud to be an official XHP dealer, offering licensed installations and expert support. You can trust us to deliver genuine software, professional service, and the best results for your BMW.',
                                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              
                              // Key Features (expandable)
                              InkWell(
                                onTap: () => setState(() => _isKeyFeaturesExpanded = !_isKeyFeaturesExpanded),
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '🔧 Key Features:',
                                              style: context.textStyles.bodyLarge?.semiBold.withColor(Colors.white),
                                            ),
                                          ),
                                          Icon(
                                            _isKeyFeaturesExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      if (_isKeyFeaturesExpanded) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Divider(color: Colors.white38),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          '• Up to 70% faster shift times\n'
                                          '• Smoother low-speed driving & take-off\n'
                                          '• Removed factory torque limiters\n'
                                          '• Rev-matched downshifts & sporty throttle blips\n'
                                          '• Customizable shift maps for Comfort, Sport & Manual Modes\n'
                                          '• Improved cooling logic for better gearbox protection\n'
                                          '• Launch Control (on supported models)\n'
                                          '• Available for over 200 BMW models with ZF 6HP & 8HP gearboxes',
                                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              
                              // Installation & Support (expandable)
                              InkWell(
                                onTap: () => setState(() => _isInstallationSupportExpanded = !_isInstallationSupportExpanded),
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '🔧 Installation & Support',
                                              style: context.textStyles.bodyLarge?.semiBold.withColor(Colors.white),
                                            ),
                                          ),
                                          Icon(
                                            _isInstallationSupportExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      if (_isInstallationSupportExpanded) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Divider(color: Colors.white38),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'At BimmerWise, we offer professional installation of XHP gearbox maps using genuine software licenses. We\'ll help you choose the right stage for your driving needs:\n\n'
                                          'Stage 1 – Enhanced comfort and drivability\n\n'
                                          'Stage 2 – Balanced performance for daily and spirited driving\n\n'
                                          'Stage 3 – Maximum performance for track or aggressive driving\n\n'
                                          'Let us remap your gearbox and completely transform the way your BMW drives.',
                                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              
                              // Compatibility (expandable)
                              InkWell(
                                onTap: () => setState(() => _isCompatibilityExpanded = !_isCompatibilityExpanded),
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Compatibility',
                                              style: context.textStyles.bodyLarge?.semiBold.withColor(Colors.white),
                                            ),
                                          ),
                                          Icon(
                                            _isCompatibilityExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                      if (_isCompatibilityExpanded) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        const Divider(color: Colors.white38),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'Suitable for a wide range of BMW and MINI models, both petrol and diesel, including all 1–8 Series, X Series, Z4, and MINI vehicles. Unsure about your car? Enter your VIN during checkout and we\'ll confirm compatibility and expected results.',
                                          style: context.textStyles.bodyMedium?.withColor(Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Additional notes
                              Text(
                                'Additional Notes (Optional)',
                                style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Any special requests or information...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    borderSide: const BorderSide(color: Colors.white, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Price summary
                              Container(
                                padding: AppSpacing.paddingLg,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Price:',
                                      style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                                    ),
                                    Text(
                                      '€${_basePrice.toStringAsFixed(0)}',
                                      style: context.textStyles.headlineMedium?.bold.withColor(Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              
                              // Submit button
                              ElevatedButton(
                                onPressed: _submitBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF001E50),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                child: Text(
                                  'Confirm Booking',
                                  style: context.textStyles.titleMedium?.semiBold,
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
}
