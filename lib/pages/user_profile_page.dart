import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:bimmerwise_connect/models/address_model.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:bimmerwise_connect/widgets/safe_lottie.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? scrollTo;

  const UserProfilePage({super.key, required this.userId, this.scrollTo});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _user;
  List<Vehicle> _vehicles = [];
  List<ServiceRecord> _serviceRecords = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _editProfileKey = GlobalKey();
  final GlobalKey _addressesKey = GlobalKey();
  final GlobalKey _vehiclesKey = GlobalKey();
  final GlobalKey _bookingsKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _hasScrolled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scroll only once after the first frame is rendered
    if (!_hasScrolled && widget.scrollTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_hasScrolled) {
            _scrollToSection();
            _hasScrolled = true;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection() {
    if (widget.scrollTo == null) return;
    
    GlobalKey? targetKey;
    switch (widget.scrollTo) {
      case 'edit_profile':
        targetKey = _editProfileKey;
        break;
      case 'addresses':
        targetKey = _addressesKey;
        break;
      case 'my_vehicles':
        targetKey = _vehiclesKey;
        break;
      case 'my_bookings':
        targetKey = _bookingsKey;
        break;
      case 'service_history':
        targetKey = _historyKey;
        break;
    }
    
    if (targetKey?.currentContext != null) {
      try {
        Scrollable.ensureVisible(
          targetKey!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Position at 10% from top of viewport
        );
      } catch (e) {
        debugPrint('Error scrolling to section: $e');
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userService = UserService();
      final vehicleService = VehicleService();
      final serviceRecordService = ServiceRecordService();

      // Retry fetching user with delays to handle Firestore propagation
      User? user;
      for (int i = 0; i < 3; i++) {
        user = await userService.getUserById(widget.userId);
        if (user != null) break;
        if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
      }

      if (user == null) {
        debugPrint('User not found after retries: ${widget.userId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to load profile. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      final vehicles = await vehicleService.getVehiclesByUserId(widget.userId);
      
      final List<ServiceRecord> allRecords = [];
      for (var vehicle in vehicles) {
        final records = await serviceRecordService.getRecordsByVehicleId(vehicle.id);
        allRecords.addAll(records);
      }
      
      allRecords.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

      setState(() {
        _user = user;
        _vehicles = vehicles;
        _serviceRecords = allRecords;
      });
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Selecting image...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      FilePickerResult? result;
      
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
          allowMultiple: false,
        );
      } catch (e) {
        debugPrint('FilePicker error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open file picker. Please check app permissions.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Clear loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to read image file'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Check file size (limit to 5MB to prevent crashes on some devices)
        final fileSizeInMB = file.bytes!.length / (1024 * 1024);
        if (fileSizeInMB > 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image too large (${fileSizeInMB.toStringAsFixed(1)}MB). Please select an image under 5MB.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Show uploading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Uploading image...'),
                ],
              ),
              duration: Duration(seconds: 30),
            ),
          );
        }

        try {
          final bytes = file.bytes!;
          final base64Image = base64Encode(bytes);
          final extension = file.extension?.toLowerCase() ?? 'png';
          final mimeType = extension == 'jpg' || extension == 'jpeg' 
              ? 'image/jpeg' 
              : extension == 'png' 
                  ? 'image/png' 
                  : 'image/$extension';
          final dataUrl = 'data:$mimeType;base64,$base64Image';

          final updatedUser = _user!.copyWith(
            profilePicture: dataUrl,
            updatedAt: DateTime.now(),
          );

          await UserService().updateUser(updatedUser);
          
          if (mounted) {
            setState(() => _user = updatedUser);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error encoding/uploading image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to upload image. The image may be too large or corrupted.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } else {
        // User cancelled selection
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
      }
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _editUserInfo() {
    final nameController = TextEditingController(text: _user?.name);
    final emailController = TextEditingController(text: _user?.email);
    final phoneController = TextEditingController(text: _user?.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedUser = _user!.copyWith(
                name: nameController.text.trim(),
                email: emailController.text.trim(),
                phone: phoneController.text.trim(),
                updatedAt: DateTime.now(),
              );
              await UserService().updateUser(updatedUser);
              setState(() => _user = updatedUser);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated!')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAddressDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddressDialog(
        onSave: (address) async {
          try {
            final updatedUser = _user!.copyWith(
              addresses: [..._user!.addresses, address],
            );
            await UserService().updateUser(updatedUser);
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            debugPrint('Error adding address: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error adding address: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _showEditAddressDialog(Address address) async {
    await showDialog(
      context: context,
      builder: (context) => AddressDialog(
        address: address,
        onSave: (updatedAddress) async {
          try {
            final addresses = _user!.addresses.map((a) {
              return a.id == updatedAddress.id ? updatedAddress : a;
            }).toList();
            final updatedUser = _user!.copyWith(addresses: addresses);
            await UserService().updateUser(updatedUser);
            await _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            debugPrint('Error updating address: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating address: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteAddress(Address address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final addresses = _user!.addresses.where((a) => a.id != address.id).toList();
        final updatedUser = _user!.copyWith(addresses: addresses);
        await UserService().updateUser(updatedUser);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting address: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting address: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle.model}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VehicleService().deleteVehicle(vehicle.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error deleting vehicle: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to delete vehicle'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _addVehicle() {
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final vinController = TextEditingController();
    final plateController = TextEditingController();
    final colorController = TextEditingController();
    String? selectedFuelType;
    String? selectedEngineSize;
    
    final Map<String, List<String>> engineSizesByFuel = {
      'Petrol': ['1.5L', '1.6L', '2.0L', '2.5L', '3.0L', '4.4L'],
      'Petrol Plugin Hybrid': ['1.5L', '1.6L', '2.0L', '2.5L', '3.0L', '4.4L'],
      'Diesel': ['2.0L', '3.0L'],
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'BMW Model',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFuelType,
                  decoration: const InputDecoration(
                    labelText: 'Fuel Type',
                    prefixIcon: Icon(Icons.local_gas_station),
                  ),
                  items: ['Petrol', 'Petrol Plugin Hybrid', 'Diesel'].map((fuel) {
                    return DropdownMenuItem(value: fuel, child: Text(fuel));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFuelType = value;
                      selectedEngineSize = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (selectedFuelType != null)
                  DropdownButtonFormField<String>(
                    value: selectedEngineSize,
                    decoration: const InputDecoration(
                      labelText: 'Engine Size',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: engineSizesByFuel[selectedFuelType]!.map((size) {
                      return DropdownMenuItem(value: size, child: Text(size));
                    }).toList(),
                    onChanged: (value) => setState(() => selectedEngineSize = value),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: vinController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 7,
                  decoration: const InputDecoration(
                    labelText: 'VIN (Last 7 Characters) *',
                    hintText: 'e.g., A123456',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Registration / License Plate *',
                    hintText: 'e.g., ABC-123',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    prefixIcon: Icon(Icons.palette),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (modelController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter vehicle model')),
                  );
                  return;
                }
                if (yearController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter year')),
                  );
                  return;
                }
                if (selectedFuelType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select fuel type')),
                  );
                  return;
                }
                if (selectedEngineSize == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select engine size')),
                  );
                  return;
                }
                
                // Validate VIN (must be exactly 7 characters, alphanumeric)
                final vin = vinController.text.trim();
                if (vin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter VIN number')),
                  );
                  return;
                }
                if (vin.length != 7) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('VIN must be exactly 7 characters')),
                  );
                  return;
                }
                if (!RegExp(r'^[A-Z0-9]{7}$').hasMatch(vin)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('VIN must contain only letters and numbers')),
                  );
                  return;
                }
                
                // Validate Registration/License Plate
                if (plateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter registration/license plate number')),
                  );
                  return;
                }

                final newVehicle = Vehicle(
                  id: const Uuid().v4(),
                  userId: widget.userId,
                  model: modelController.text.trim(),
                  year: yearController.text.trim(),
                  vin: vin,
                  licensePlate: plateController.text.trim(),
                  color: colorController.text.trim(),
                  fuelType: selectedFuelType,
                  engineSize: selectedEngineSize,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await VehicleService().addVehicle(newVehicle);
                await _loadData();
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vehicle added!')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addServiceRecord() {
    String? selectedVehicleId;
    final serviceTypeController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStatus = 'Booking In Progress';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Service Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedVehicleId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Choose vehicle'),
                  items: _vehicles.map((vehicle) {
                    return DropdownMenuItem(
                      value: vehicle.id,
                      child: Text('${vehicle.model} (${vehicle.licensePlate})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedVehicleId = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serviceTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Service Type',
                    prefixIcon: Icon(Icons.build),
                    hintText: 'e.g., Regular Service, Diagnostic',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Service Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                  onTap: () async {
                    final now = DateTime.now();
                    final firstDate = DateTime(2020);
                    final lastDate = DateTime(now.year, now.month, now.day);
                    
                    // Ensure initialDate is within valid range
                    DateTime initialDate = selectedDate;
                    if (initialDate.isBefore(firstDate)) {
                      initialDate = firstDate;
                    } else if (initialDate.isAfter(lastDate)) {
                      initialDate = lastDate;
                    }
                    
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.info),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Booking In Progress',
                    'Booking Confirmed',
                    'Booking Canceled',
                    'Completed',
                  ].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedStatus = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedVehicleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a vehicle')),
                  );
                  return;
                }
                if (serviceTypeController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter service type')),
                  );
                  return;
                }

                final newRecord = ServiceRecord(
                  id: const Uuid().v4(),
                  vehicleId: selectedVehicleId!,
                  userId: widget.userId,
                  serviceType: serviceTypeController.text.trim(),
                  description: descriptionController.text.trim(),
                  serviceDate: selectedDate,
                  cost: 0.0,
                  status: selectedStatus,
                  progress: selectedStatus == 'Completed' ? 100 : selectedStatus == 'Booking Confirmed' ? 50 : 25,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ServiceRecordService().addRecord(newRecord);
                await _loadData();
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service record added!')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _modifyBooking(ServiceRecord record, Vehicle vehicle) async {
    final descriptionController = TextEditingController(text: record.description);
    DateTime selectedDate = record.serviceDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(record.serviceDate);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modify Booking'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service: ${record.serviceType}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vehicle: ${vehicle.model}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Appointment Date & Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                  onTap: () async {
                    final now = DateTime.now();
                    final firstDate = DateTime(now.year, now.month, now.day);
                    final lastDate = firstDate.add(const Duration(days: 365));
                    
                    // Ensure initialDate is within valid range
                    DateTime initialDate = selectedDate;
                    if (initialDate.isBefore(firstDate)) {
                      initialDate = firstDate;
                    } else if (initialDate.isAfter(lastDate)) {
                      initialDate = lastDate;
                    }
                    
                    // If initialDate is Sunday, move to Monday to match selectableDayPredicate
                    if (initialDate.weekday == 7) {
                      initialDate = initialDate.add(const Duration(days: 1));
                    }
                    
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      selectableDayPredicate: (DateTime date) {
                        // Disable Sundays
                        return date.weekday != 7;
                      },
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(selectedTime.format(context)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate booking time
                if (!_isValidBookingTime(selectedDate, selectedTime)) {
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
                Navigator.of(context).pop(true);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final scheduledDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        final updatedRecord = record.copyWith(
          serviceDate: scheduledDateTime,
          description: descriptionController.text.trim(),
          status: 'Booking In Progress',
          progress: 25,
          updatedAt: DateTime.now(),
        );

        await ServiceRecordService().updateRecord(updatedRecord);
        
        // Send notification to all admin users about booking modification
        if (_user != null) {
          await NotificationService().sendBookingModifiedNotificationToAllAdmins(
            bookingId: record.id,
            customerName: _user!.name,
            customerEmail: _user!.email,
            serviceName: record.serviceType,
            vehicleInfo: vehicle.model,
            newBookingDate: scheduledDateTime,
          );
        }
        
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking modified! Admin will confirm your new appointment.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating booking: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to update booking'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmCollection(ServiceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Vehicle Collection'),
        content: Text(
          'Please confirm that you have collected your ${_vehicles.firstWhere((v) => v.id == record.vehicleId).model} from our service center.\n\nService: ${record.serviceType}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Collection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final updatedRecord = record.copyWith(
          status: 'Collected',
          progress: 100,
          updatedAt: DateTime.now(),
        );

        await ServiceRecordService().updateRecord(updatedRecord);
        
        // Show success animation
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: SafeLottie(
                        assetPath: 'assets/documents/Check_Mark_-_Success.json',
                        width: 200,
                        height: 200,
                        repeat: false,
                        fallbackIcon: Icons.check_circle,
                        fallbackColor: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Vehicle Collected!',
                      style: context.textStyles.titleLarge?.semiBold.withColor(
                        Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thank you for choosing BIMMERWISE',
                      style: context.textStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection confirmed! Thank you for your business.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error confirming collection: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to confirm collection'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelBooking(ServiceRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel the booking for "${record.serviceType}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get vehicle info for notification
        final vehicle = _vehicles.firstWhere((v) => v.id == record.vehicleId);
        
        final updatedRecord = record.copyWith(
          status: 'Booking Canceled',
          progress: 0,
          updatedAt: DateTime.now(),
        );

        await ServiceRecordService().updateRecord(updatedRecord);
        
        // Send notification to all admin users about booking cancellation
        if (_user != null) {
          await NotificationService().sendBookingCanceledNotificationToAllAdmins(
            bookingId: record.id,
            customerName: _user!.name,
            customerEmail: _user!.email,
            serviceName: record.serviceType,
            vehicleInfo: vehicle.model,
          );
        }
        
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking canceled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error canceling booking: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to cancel booking'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  String _getStatusDescription(ServiceRecord record) {
    switch (record.status) {
      case 'Booking In Progress':
        return 'Your booking is being processed';
      case 'Booking Confirmed':
        return 'Your booking has been confirmed';
      case 'Booking Canceled':
        return 'This booking was canceled';
      case 'Completed':
        return 'Service complete - Ready to pick up';
      case 'Collected':
        return 'Vehicle has been collected';
      default:
        return record.status;
    }
  }

  Color _getStatusColor(ServiceRecord record) {
    switch (record.status) {
      case 'Booking In Progress':
        return Colors.orange;
      case 'Booking Confirmed':
        return const Color(0xFF3B9DD8);
      case 'Booking Canceled':
        return Colors.red;
      case 'Completed':
        return Colors.green;
      case 'Collected':
        return Colors.blue;
      default:
        return const Color(0xFF3B9DD8);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF001E50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF001E50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        body: const Center(child: Text('User not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_user?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              onPressed: () => context.push('/admin-panel'),
              tooltip: 'Admin Panel',
            ),
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
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
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickProfilePicture,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          backgroundImage: _user!.profilePicture != null
                              ? MemoryImage(
                                  base64Decode(_user!.profilePicture!.split(',').last),
                                )
                              : null,
                          child: _user!.profilePicture == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Color(0xFF001E50),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF3B9DD8),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: _pickProfilePicture,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _user!.name,
                  style: context.textStyles.headlineMedium?.semiBold.withColor(Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _user!.email,
                  style: context.textStyles.bodyLarge?.withColor(Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _user!.phone,
                  style: context.textStyles.bodyMedium?.withColor(Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  key: _editProfileKey,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _editUserInfo,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showAddAddressDialog,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Manage Address'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF3B9DD8),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                                if (_user!.addresses.isNotEmpty)
                  Text(
                    key: _addressesKey,
                    'My Addresses (${_user!.addresses.length})',
                    style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                  ),
                if (_user!.addresses.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),
                if (_user!.addresses.isNotEmpty)
                  ..._user!.addresses.map((address) => AddressCardWidget(
                        address: address,
                        onEdit: () => _showEditAddressDialog(address),
                        onDelete: () => _deleteAddress(address),
                      )),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  key: _vehiclesKey,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Vehicles',
                      style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addVehicle,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_vehicles.isEmpty)
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 48,
                          color: Color(0xFF001E50),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No vehicles added yet',
                          style: context.textStyles.bodyLarge?.withColor(
                            const Color(0xFF001E50),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _addVehicle,
                          child: const Text('Add Your First Vehicle'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._vehicles.map((vehicle) => VehicleCard(
                        vehicle: vehicle,
                        onEdit: _loadData,
                        onDelete: () => _deleteVehicle(vehicle),
                      )),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  key: _bookingsKey,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Booked Service',
                      style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_serviceRecords.any((record) => record.status != 'Completed' && record.status != 'Collected' && record.status != 'Booking Canceled'))
                  ..._serviceRecords
                      .where((record) => record.status != 'Completed' && record.status != 'Collected' && record.status != 'Booking Canceled')
                      .map((record) {
                    final vehicle = _vehicles.firstWhere(
                      (v) => v.id == record.vehicleId,
                      orElse: () => Vehicle(
                        id: '',
                        userId: '',
                        model: 'Unknown',
                        year: '',
                        vin: '',
                        licensePlate: '',
                        color: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return ServiceRecordCard(
                      record: record,
                      vehicle: vehicle,
                      statusColor: _getStatusColor(record),
                      statusDescription: _getStatusDescription(record),
                      onModify: () => _modifyBooking(record, vehicle),
                      onCancel: () => _cancelBooking(record),
                    );
                  })
                else
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 48,
                          color: Color(0xFF001E50),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No active bookings',
                          style: context.textStyles.bodyLarge?.withColor(
                            const Color(0xFF001E50),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  key: _historyKey,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Service History',
                      style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _vehicles.isEmpty ? null : _addServiceRecord,
                      color: Colors.white,
                      tooltip: _vehicles.isEmpty ? 'Add a vehicle first' : 'Add service record',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_serviceRecords.any((record) => record.status == 'Completed' || record.status == 'Collected'))
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 48,
                          color: Color(0xFF001E50),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No service history yet',
                          style: context.textStyles.bodyLarge?.withColor(
                            const Color(0xFF001E50),
                          ),
                        ),
                        if (_vehicles.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: _addServiceRecord,
                            child: const Text('Add Service Record'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  ..._serviceRecords
                      .where((record) => record.status == 'Completed' || record.status == 'Collected')
                      .map((record) {
                    final vehicle = _vehicles.firstWhere(
                      (v) => v.id == record.vehicleId,
                      orElse: () => Vehicle(
                        id: '',
                        userId: '',
                        model: 'Unknown',
                        year: '',
                        vin: '',
                        licensePlate: '',
                        color: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return ServiceRecordCard(
                      record: record,
                      vehicle: vehicle,
                      statusColor: _getStatusColor(record),
                      statusDescription: _getStatusDescription(record),
                      onConfirmCollection: record.status == 'Completed' ? () => _confirmCollection(record) : null,
                    );
                  }),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cancelled Bookings',
                      style: context.textStyles.titleLarge?.semiBold.withColor(Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_serviceRecords.any((record) => record.status == 'Booking Canceled'))
                  Container(
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cancel,
                          size: 48,
                          color: Color(0xFF001E50),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No cancelled bookings',
                          style: context.textStyles.bodyLarge?.withColor(
                            const Color(0xFF001E50),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._serviceRecords
                      .where((record) => record.status == 'Booking Canceled')
                      .map((record) {
                    final vehicle = _vehicles.firstWhere(
                      (v) => v.id == record.vehicleId,
                      orElse: () => Vehicle(
                        id: '',
                        userId: '',
                        model: 'Unknown',
                        year: '',
                        vin: '',
                        licensePlate: '',
                        color: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                    return ServiceRecordCard(
                      record: record,
                      vehicle: vehicle,
                      statusColor: _getStatusColor(record),
                      statusDescription: _getStatusDescription(record),
                    );
                  }),
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

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(vehicle.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(
                Icons.delete,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Delete',
                style: context.textStyles.titleMedium?.semiBold.withColor(Colors.white),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: const Color(0xFF001E50).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  color: Color(0xFF001E50),
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.model,
                        style: context.textStyles.titleMedium?.semiBold.withColor(const Color(0xFF001E50)),
                      ),
                      Text(
                        '${vehicle.year} • ${vehicle.color}',
                        style: context.textStyles.bodySmall?.withColor(
                          const Color(0xFF001E50).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.swipe_left,
                  color: const Color(0xFF001E50).withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (vehicle.fuelType != null)
              _InfoRow(icon: Icons.local_gas_station, label: 'Fuel', value: vehicle.fuelType!),
            if (vehicle.engineSize != null)
              _InfoRow(icon: Icons.speed, label: 'Engine', value: vehicle.engineSize!),
            _InfoRow(icon: Icons.vpn_key, label: 'VIN', value: vehicle.vin),
            _InfoRow(icon: Icons.credit_card, label: 'Plate', value: vehicle.licensePlate),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF001E50).withValues(alpha: 0.7)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label: ',
            style: context.textStyles.bodySmall?.withColor(
              const Color(0xFF001E50).withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: context.textStyles.bodySmall?.semiBold.withColor(const Color(0xFF001E50)),
          ),
        ],
      ),
    );
  }
}

class ServiceRecordCard extends StatefulWidget {
  final ServiceRecord record;
  final Vehicle vehicle;
  final Color statusColor;
  final String statusDescription;
  final VoidCallback? onModify;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirmCollection;

  const ServiceRecordCard({
    super.key,
    required this.record,
    required this.vehicle,
    required this.statusColor,
    required this.statusDescription,
    this.onModify,
    this.onCancel,
    this.onConfirmCollection,
  });

  @override
  State<ServiceRecordCard> createState() => _ServiceRecordCardState();
}

class _ServiceRecordCardState extends State<ServiceRecordCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.record.progress / 100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: widget.statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.serviceType,
                      style: context.textStyles.titleMedium?.semiBold.withColor(const Color(0xFF001E50)),
                    ),
                    Text(
                      widget.vehicle.model,
                      style: context.textStyles.bodySmall?.withColor(
                        const Color(0xFF001E50).withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: widget.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  widget.record.status,
                  style: context.textStyles.bodySmall?.semiBold.withColor(widget.statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.statusDescription,
            style: context.textStyles.bodyMedium?.withColor(
              const Color(0xFF001E50).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: context.textStyles.bodySmall?.withColor(
                        const Color(0xFF001E50).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: LinearProgressIndicator(
                            value: _animation.value,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF001E50).withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(widget.statusColor),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Text(
                    '${(_animation.value * 100).toInt()}%',
                    style: context.textStyles.titleLarge?.semiBold.withColor(widget.statusColor),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(widget.record.serviceDate),
                    style: context.textStyles.bodySmall?.withColor(
                      const Color(0xFF001E50).withValues(alpha: 0.7),
                    ),
                  ),
                  if (widget.record.mileage != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          size: 14,
                          color: const Color(0xFF001E50).withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.record.mileage} km',
                          style: context.textStyles.bodySmall?.withColor(
                            const Color(0xFF001E50).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (widget.record.cost > 0)
                Text(
                  '€${widget.record.cost.toStringAsFixed(2)}',
                  style: context.textStyles.titleMedium?.semiBold.withColor(
                    const Color(0xFF001E50),
                  ),
                ),
            ],
          ),
          if (widget.record.adminNotes != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: AppSpacing.paddingSm,
              decoration: BoxDecoration(
                color: const Color(0xFF001E50).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 14,
                        color: const Color(0xFF001E50).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Admin Notes:',
                        style: context.textStyles.labelSmall?.semiBold.withColor(
                          const Color(0xFF001E50).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.record.adminNotes!,
                    style: context.textStyles.bodySmall?.withColor(
                      const Color(0xFF001E50),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.record.attachedImages != null && widget.record.attachedImages!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.record.attachedImages!.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.memory(
                                base64Decode(widget.record.attachedImages![index].split(',').last),
                                fit: BoxFit.contain,
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: const Color(0xFF001E50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          base64Decode(widget.record.attachedImages![index].split(',').last),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (widget.onModify != null || widget.onCancel != null || widget.onConfirmCollection != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            if (widget.onConfirmCollection != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onConfirmCollection,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Vehicle Collection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  if (widget.onModify != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onModify,
                        icon: const Icon(Icons.edit),
                        label: const Text('Modify'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B9DD8),
                          side: const BorderSide(color: Color(0xFF3B9DD8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (widget.onModify != null && widget.onCancel != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (widget.onCancel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class AddressCardWidget extends StatelessWidget {
  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AddressCardWidget({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: const Color(0xFF001E50).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.fullName,
                      style: context.textStyles.titleMedium?.semiBold.withColor(const Color(0xFF001E50)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B9DD8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        address.type.toUpperCase(),
                        style: context.textStyles.labelSmall?.semiBold.withColor(
                          const Color(0xFF3B9DD8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF3B9DD8)),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            address.formattedAddress,
            style: context.textStyles.bodyMedium?.withColor(
              const Color(0xFF001E50).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 14,
                color: const Color(0xFF001E50).withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                address.phone,
                style: context.textStyles.bodySmall?.withColor(
                  const Color(0xFF001E50).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddressDialog extends StatefulWidget {
  final Address? address;
  final Function(Address) onSave;

  const AddressDialog({
    super.key,
    this.address,
    required this.onSave,
  });

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _streetController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.address?.fullName ?? '');
    _streetController = TextEditingController(text: widget.address?.street ?? '');
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _stateController = TextEditingController(text: widget.address?.state ?? '');
    _postalCodeController = TextEditingController(text: widget.address?.postalCode ?? '');
    _countryController = TextEditingController(text: widget.address?.country ?? '');
    _phoneController = TextEditingController(text: widget.address?.phone ?? '');
    _selectedType = widget.address?.type ?? 'both';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: AppSpacing.paddingLg,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.address == null ? 'Add Address' : 'Edit Address',
                  style: context.textStyles.headlineSmall?.semiBold,
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Address Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'shipping', child: Text('Shipping')),
                    DropdownMenuItem(value: 'billing', child: Text('Billing')),
                    DropdownMenuItem(value: 'both', child: Text('Both (Shipping & Billing)')),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Postal Code',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final address = Address(
                            id: widget.address?.id ?? const Uuid().v4(),
                            fullName: _fullNameController.text,
                            street: _streetController.text,
                            city: _cityController.text,
                            state: _stateController.text,
                            postalCode: _postalCodeController.text,
                            country: _countryController.text,
                            phone: _phoneController.text,
                            type: _selectedType,
                            createdAt: widget.address?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                          );
                          widget.onSave(address);
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B9DD8),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
