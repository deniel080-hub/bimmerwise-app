import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';

class RegularServiceBookingPage extends StatefulWidget {
  final String userId;

  const RegularServiceBookingPage({
    super.key,
    required this.userId,
  });

  @override
  State<RegularServiceBookingPage> createState() => _RegularServiceBookingPageState();
}

class _RegularServiceBookingPageState extends State<RegularServiceBookingPage> {
  bool _isLoading = true;
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  String _userName = '';
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  String? _selectedFuelType;
  String? _selectedEngineSize;
  String? _selectedPaymentMethod;
  
  bool _includeCabinFilter = false;
  bool _includeSparkPlug = false;
  bool _includeFuelFilter = false;
  
  final _guestMakeController = TextEditingController(text: 'BMW');
  final _guestModelController = TextEditingController();
  final _guestYearController = TextEditingController();
  final _guestRegistrationController = TextEditingController();
  
  final List<String> _fuelTypes = ['Petrol', 'Petrol Plugin Hybrid', 'Diesel'];
  final Map<String, List<String>> _engineSizes = {
    'Petrol': ['1.5L', '1.6L', '2.0L', '2.5L', '3.0L', '4.4L'],
    'Petrol Plugin Hybrid': ['2.0L', '3.0L'],
    'Diesel': ['2.0L', '3.0L'],
  };
  
  final Map<String, Map<String, double>> _pricingTable = {
    'Petrol': {
      '1.5L': 300.0,
      '1.6L': 300.0,
      '2.0L': 350.0,
      '2.5L': 375.0,
      '3.0L': 400.0,
      '4.4L': 475.0,
    },
    'Petrol Plugin Hybrid': {
      '2.0L': 350.0,
      '3.0L': 400.0,
    },
    'Diesel': {
      '2.0L': 350.0,
      '3.0L': 400.0,
    },
  };

  @override
  void dispose() {
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
        _vehicles = vehicles.map((v) => <String, dynamic>{
          'id': v.id,
          'display': '${v.year} ${v.model} (${v.licensePlate})',
          'model': v.model,
          'year': v.year,
          'fuelType': v.fuelType ?? '',
          'engineSize': v.engineSize ?? '',
        }).toList();
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'];
          _autoPopulateVehicleDetails();
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

  void _autoPopulateVehicleDetails() {
    if (_selectedVehicleId == null) return;
    final selectedVehicle = _vehicles.firstWhere(
      (v) => v['id'] == _selectedVehicleId,
      orElse: () => <String, dynamic>{},
    );
    if (selectedVehicle.isNotEmpty) {
      final fuelType = selectedVehicle['fuelType'] as String?;
      final engineSize = selectedVehicle['engineSize'] as String?;
      
      if (fuelType != null && fuelType.isNotEmpty && _fuelTypes.contains(fuelType)) {
        setState(() {
          _selectedFuelType = fuelType;
          if (engineSize != null && engineSize.isNotEmpty && _engineSizes[fuelType]?.contains(engineSize) == true) {
            _selectedEngineSize = engineSize;
          } else {
            _selectedEngineSize = null;
          }
        });
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

  double? _getCurrentPrice() {
    if (_selectedFuelType != null && _selectedEngineSize != null) {
      return _pricingTable[_selectedFuelType!]?[_selectedEngineSize!];
    }
    return null;
  }

  double _getSparkPlugPrice() {
    if (_selectedFuelType == 'Petrol' && _selectedEngineSize != null) {
      if (_selectedEngineSize == '1.6L' || _selectedEngineSize == '2.0L') {
        return 250.0;
      } else if (_selectedEngineSize == '3.0L') {
        return 325.0;
      }
    } else if (_selectedFuelType == 'Petrol Plugin Hybrid' && _selectedEngineSize != null) {
      if (_selectedEngineSize == '2.0L') {
        return 250.0;
      } else if (_selectedEngineSize == '3.0L') {
        return 325.0;
      }
    }
    return 0.0;
  }

  bool _canShowSparkPlug() {
    if (_selectedFuelType == 'Petrol' && _selectedEngineSize != null) {
      return _selectedEngineSize == '1.6L' || _selectedEngineSize == '2.0L' || _selectedEngineSize == '3.0L';
    } else if (_selectedFuelType == 'Petrol Plugin Hybrid' && _selectedEngineSize != null) {
      return _selectedEngineSize == '2.0L' || _selectedEngineSize == '3.0L';
    }
    return false;
  }

  bool _canShowFuelFilter() {
    return _selectedFuelType == 'Diesel' && _selectedEngineSize != null;
  }

  double _getTotalPrice() {
    double total = _getCurrentPrice() ?? 0.0;
    if (_includeCabinFilter) total += 90.0;
    if (_includeSparkPlug) total += _getSparkPlugPrice();
    if (_includeFuelFilter) total += 110.0;
    return total;
  }

  bool _validateForm() {
    if (_vehicles.isEmpty) {
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

    if (_selectedFuelType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select fuel type'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }

    if (_selectedEngineSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select engine size'),
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
      
      if (_vehicles.isEmpty) {
        final vehicleService = VehicleService();
        final userService = UserService();
        
        final user = await userService.getUserById(widget.userId);
        if (user == null) {
          throw Exception('User not found');
        }
        
        final vehicle = Vehicle(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: widget.userId,
          model: '${_guestMakeController.text.trim()} ${_guestModelController.text.trim()}',
          year: _guestYearController.text.trim(),
          vin: 'N/A',
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

      final price = _getTotalPrice();
      
      final List<String> extras = [];
      if (_includeCabinFilter) extras.add('Cabin Filter (€90)');
      if (_includeSparkPlug) extras.add('Spark Plug Replacement (€${_getSparkPlugPrice().toStringAsFixed(0)})');
      if (_includeFuelFilter) extras.add('Fuel Filter (€110)');
      
      final description = 'Regular Service\n'
          'Fuel Type: $_selectedFuelType\n'
          'Engine Size: $_selectedEngineSize\n'
          '${extras.isNotEmpty ? 'Extras: ${extras.join(', ')}\n' : ''}'
          'Payment: $_selectedPaymentMethod'
          '${_notesController.text.trim().isNotEmpty ? '\nNotes: ${_notesController.text.trim()}' : ''}';

      final serviceRecord = ServiceRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vehicleId: vehicleId,
        userId: widget.userId,
        serviceType: 'Regular Service',
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
            serviceName: 'Regular Service',
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
          'Regular Service',
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
                          Icon(
                            Icons.verified,
                            size: 70,
                            color: Colors.white,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'BMW Regular Service',
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
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Original BMW Parts',
                                        style: context.textStyles.bodyMedium?.semiBold.withColor(Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Registered BMW Garage',
                                        style: context.textStyles.bodyMedium?.semiBold.withColor(Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Online BMW Service History Updated',
                                        style: context.textStyles.bodyMedium?.semiBold.withColor(Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    Text(
                      _vehicles.isEmpty ? 'Vehicle Information' : 'Select Your Vehicle',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_vehicles.isEmpty)
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
                      Column(
                        children: _vehicles.map((vehicle) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedVehicleId = vehicle['id']);
                              _autoPopulateVehicleDetails();
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
                    
                    Text(
                      'Select Fuel Type',
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: _fuelTypes.map((fuelType) {
                        final isSelected = _selectedFuelType == fuelType;
                        IconData icon;
                        if (fuelType == 'Petrol') {
                          icon = Icons.local_gas_station;
                        } else if (fuelType == 'Petrol Plugin Hybrid') {
                          icon = Icons.electrical_services;
                        } else {
                          icon = Icons.oil_barrel;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFuelType = fuelType;
                                _selectedEngineSize = null;
                                _includeSparkPlug = false;
                                _includeFuelFilter = false;
                                _includeCabinFilter = false;
                              });
                            },
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
                                    icon,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      fuelType,
                                      style: context.textStyles.titleMedium?.semiBold,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    if (_selectedFuelType != null) ...[
                      Text(
                        'Select Engine Size',
                        style: context.textStyles.titleLarge?.semiBold,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Column(
                        children: _engineSizes[_selectedFuelType!]!.map((engineSize) {
                          final price = _pricingTable[_selectedFuelType!]![engineSize]!;
                          final isSelected = _selectedEngineSize == engineSize;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedEngineSize = engineSize;
                                // Reset extras when engine size changes
                                _includeSparkPlug = false;
                                _includeFuelFilter = false;
                              }),
                              child: Container(
                                padding: AppSpacing.paddingMd,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.secondary,
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.speed,
                                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        engineSize,
                                        style: context.textStyles.titleMedium?.bold.withColor(
                                          isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '€${price.toStringAsFixed(0)}',
                                      style: context.textStyles.titleLarge?.bold.withColor(
                                        isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    
                    if (_selectedEngineSize != null) ...[
                      Text(
                        'Optional Extras',
                        style: context.textStyles.titleLarge?.semiBold,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      CheckboxListTile(
                        value: _includeCabinFilter,
                        onChanged: (value) => setState(() => _includeCabinFilter = value ?? false),
                        title: Text(
                          'Cabin Filter Replacement',
                          style: context.textStyles.titleSmall?.semiBold,
                        ),
                        subtitle: Text(
                          'Replace cabin air filter for cleaner air',
                          style: context.textStyles.bodySmall?.withColor(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '€90',
                            style: context.textStyles.titleSmall?.bold.withColor(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        tileColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        contentPadding: AppSpacing.paddingMd,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      
                      if (_canShowSparkPlug()) ...[
                        CheckboxListTile(
                          value: _includeSparkPlug,
                          onChanged: (value) => setState(() => _includeSparkPlug = value ?? false),
                          title: Text(
                            'Spark Plug Replacement',
                            style: context.textStyles.titleSmall?.semiBold,
                          ),
                          subtitle: Text(
                            'Replace spark plugs for better performance',
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '€${_getSparkPlugPrice().toStringAsFixed(0)}',
                              style: context.textStyles.titleSmall?.bold.withColor(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          tileColor: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          contentPadding: AppSpacing.paddingMd,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      
                      if (_canShowFuelFilter()) ...[
                        CheckboxListTile(
                          value: _includeFuelFilter,
                          onChanged: (value) => setState(() => _includeFuelFilter = value ?? false),
                          title: Text(
                            'Fuel Filter Replacement',
                            style: context.textStyles.titleSmall?.semiBold,
                          ),
                          subtitle: Text(
                            'Replace fuel filter for better engine protection',
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              '€110',
                              style: context.textStyles.titleSmall?.bold.withColor(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          tileColor: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          contentPadding: AppSpacing.paddingMd,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    
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
                    
                    if (_getCurrentPrice() != null)
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
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Base Service:',
                                  style: context.textStyles.titleSmall,
                                ),
                                Text(
                                  '€${_getCurrentPrice()!.toStringAsFixed(0)}',
                                  style: context.textStyles.titleSmall?.semiBold,
                                ),
                              ],
                            ),
                            if (_includeCabinFilter || _includeSparkPlug || _includeFuelFilter) ...[
                              const SizedBox(height: AppSpacing.sm),
                              if (_includeCabinFilter)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Cabin Filter:',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                    Text(
                                      '€90',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              if (_includeSparkPlug) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Spark Plugs:',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                    Text(
                                      '€${_getSparkPlugPrice().toStringAsFixed(0)}',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                              if (_includeFuelFilter) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Fuel Filter:',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                    Text(
                                      '€110',
                                      style: context.textStyles.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(height: AppSpacing.lg),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Price:',
                                  style: context.textStyles.titleLarge?.semiBold,
                                ),
                                Text(
                                  '€${_getTotalPrice().toStringAsFixed(0)}',
                                  style: context.textStyles.headlineMedium?.bold.withColor(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    
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
