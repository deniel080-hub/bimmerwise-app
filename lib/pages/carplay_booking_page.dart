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

class CarplayBookingPage extends StatefulWidget {
  final String userId;

  const CarplayBookingPage({
    super.key,
    required this.userId,
  });

  @override
  State<CarplayBookingPage> createState() => _CarplayBookingPageState();
}

class _CarplayBookingPageState extends State<CarplayBookingPage> {
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  String _userName = '';
  final _vinController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  String? _selectedSystemType;
  String? _selectedPaymentMethod;
  
  // Guest vehicle information
  final _guestMakeController = TextEditingController(text: 'BMW');
  final _guestModelController = TextEditingController();
  final _guestYearController = TextEditingController();
  final _guestRegistrationController = TextEditingController();
  
  final Map<String, double> _systemPrices = {
    'NBT EVO ID4': 285.0,
    'NBT EVO ID5/6': 170.0,
    'ENTRYNAV2 / WAY': 285.0,
  };

  final Map<String, String> _systemDescriptions = {
    'NBT EVO ID4': 'We present flashing (programming) from NBTEvo iDrive 4 to iDrive 6, Your map version has to be NBTEvo_XXXXX (NBTEvo_A / NBTEvo_C / NBTEvo_D / NBTEvo_E / NBTEvo_F).',
    'NBT EVO ID5/6': 'Check Firmware Version You will see NBTEVO_XXXXX Fullscreen Carplay Support without software update NBTEvo_N / O / P / Q / R / S / T / U / W / V / X / Y',
    'ENTRYNAV2 / WAY': 'FULLSCREEN included (If software supports it).\nHeadunit has to be map \'WAY\' version or non-nav headunit. Requirement is WLAN port on Headunit, This can be checked in our Garage for free of charge',
  };

  @override
  void dispose() {
    _vinController.dispose();
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
          'vin': v.vin,
        }).toList();
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
          // Auto-fill VIN from first vehicle
          final firstVehicleVin = _vehicles.first['vin'] as String?;
          if (firstVehicleVin != null && firstVehicleVin.length >= 7) {
            _vinController.text = firstVehicleVin.substring(firstVehicleVin.length - 7).toUpperCase();
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

    final vin = _vinController.text.trim();
    if (vin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter VIN number'),
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
    if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(vin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('VIN must contain only letters and numbers'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    if (_selectedSystemType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a system type'),
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

      final price = _systemPrices[_selectedSystemType]!;
      
      final description = 'Wireless Apple Carplay Activation - $_selectedSystemType\n'
          'VIN: ${_vinController.text.trim()}\n'
          'Payment: $_selectedPaymentMethod'
          '${_notesController.text.trim().isNotEmpty ? '\nNotes: ${_notesController.text.trim()}' : ''}';

      final serviceRecord = ServiceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: vehicleId,
        userId: widget.userId,
        serviceType: 'Wireless Apple Carplay Activation',
        description: description,
        serviceDate: scheduledDateTime,
        cost: price,
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
          final vehicle = _vehicles.firstWhere((v) => v['id'] == vehicleId);
          await NotificationService().sendBookingCreatedNotificationToAllAdmins(
            bookingId: serviceRecord.id,
            customerName: user.name,
            customerEmail: user.email,
            serviceName: 'Wireless Apple Carplay Activation',
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
                  ? 'Booking created! Payment of €${price.toStringAsFixed(0)} will be processed.'
                  : 'Booking created! Please bring €${price.toStringAsFixed(0)} in cash.'
            ),
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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Wireless Apple CarPlay',
          style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    // Service header with image
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
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Image.asset(
                              'assets/images/640.png',
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Wireless Apple CarPlay Activation',
                            style: context.textStyles.titleLarge?.bold.withColor(Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Welcome, $_userName',
                            style: context.textStyles.bodyMedium?.withColor(Colors.white.withValues(alpha: 0.95)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Vehicle selection or information
                    Text(
                      _vehicles.isEmpty ? 'Vehicle Information' : 'Select Your Vehicle',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_vehicles.isEmpty)
                      // Guest vehicle information form
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _guestMakeController,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Make',
                              hintText: 'e.g., BMW, Mercedes',
                              prefixIcon: const Icon(Icons.directions_car),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _guestModelController,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Model',
                              hintText: 'e.g., X5, E-Class',
                              prefixIcon: const Icon(Icons.car_repair),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _guestYearController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Year',
                              hintText: 'e.g., 2020',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _guestRegistrationController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Registration/License Plate',
                              hintText: 'e.g., ABC-1234',
                              prefixIcon: const Icon(Icons.confirmation_number),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
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
                              });
                            },
                            child: Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: _selectedVehicleId == vehicle['id']
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _selectedVehicleId == vehicle['id']
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                  width: _selectedVehicleId == vehicle['id'] ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      vehicle['display'],
                                      style: context.textStyles.titleSmall?.semiBold,
                                    ),
                                  ),
                                  if (_selectedVehicleId == vehicle['id'])
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // VIN number input
                    Text(
                      'VIN Number (Last 7 Characters)',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _vinController,
                      maxLength: 7,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g., A123456',
                        helperText: 'Exactly 7 characters (letters and numbers)',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        counterText: '${_vinController.text.length}/7',
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // System type selection
                    Text(
                      'Select System Type',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._systemPrices.entries.map((entry) {
                      final isSelected = _selectedSystemType == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _selectedSystemType = entry.key),
                              child: Container(
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.apple,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: context.textStyles.titleSmall?.semiBold,
                                          ),
                                          if (entry.key == 'NBT EVO ID5/6')
                                            Text(
                                              'Some models may cost €285',
                                              style: context.textStyles.bodySmall?.withColor(
                                                Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '€${entry.value.toStringAsFixed(0)}',
                                      style: context.textStyles.titleLarge?.bold.withColor(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected && _systemDescriptions.containsKey(entry.key)) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                width: double.infinity,
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _systemDescriptions[entry.key]!,
                                        style: context.textStyles.bodySmall?.withColor(
                                          Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Payment method selection
                    Text(
                      'Payment Method',
                      style: context.textStyles.titleLarge?.semiBold,
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
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _selectedPaymentMethod == 'Cash'
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                  width: _selectedPaymentMethod == 'Cash' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payments,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Cash',
                                    style: context.textStyles.titleSmall?.semiBold,
                                  ),
                                  if (_selectedPaymentMethod == 'Cash')
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
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
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _selectedPaymentMethod == 'Card'
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                  width: _selectedPaymentMethod == 'Card' ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.credit_card,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Card',
                                    style: context.textStyles.titleSmall?.semiBold,
                                  ),
                                  if (_selectedPaymentMethod == 'Card')
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
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
                    
                    // Additional notes
                    Text(
                      'Additional Notes (Optional)',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Any special requests or information...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Price summary
                    if (_selectedSystemType != null)
                      Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Price:',
                              style: context.textStyles.titleLarge?.semiBold,
                            ),
                            Text(
                              '€${_systemPrices[_selectedSystemType]!.toStringAsFixed(0)}',
                              style: context.textStyles.headlineMedium?.bold.withColor(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Submit button
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
