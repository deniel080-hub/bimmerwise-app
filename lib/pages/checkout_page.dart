import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/cart_service.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/order_service.dart';
import 'package:bimmerwise_connect/models/cart_item_model.dart';
import 'package:bimmerwise_connect/models/address_model.dart';
import 'package:bimmerwise_connect/models/order_model.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();
  
  List<CartItem> _cartItems = [];
  User? _currentUser;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  
  Address? _selectedShippingAddress;
  Address? _selectedBillingAddress;
  bool _useDifferentShippingAddress = false;
  bool _useDifferentBillingAddress = false;
  String _shippingMethod = 'standard';
  
  final _guestFormKey = GlobalKey<FormState>();
  final _shippingFormKey = GlobalKey<FormState>();
  final _billingFormKey = GlobalKey<FormState>();
  
  final _guestNameController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  
  final _shippingFullNameController = TextEditingController();
  final _shippingStreetController = TextEditingController();
  final _shippingCityController = TextEditingController();
  final _shippingStateController = TextEditingController();
  final _shippingPostalCodeController = TextEditingController();
  final _shippingCountryController = TextEditingController();
  final _shippingPhoneController = TextEditingController();
  
  final _billingFullNameController = TextEditingController();
  final _billingStreetController = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingPostalCodeController = TextEditingController();
  final _billingCountryController = TextEditingController();
  final _billingPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestEmailController.dispose();
    _guestPhoneController.dispose();
    _shippingFullNameController.dispose();
    _shippingStreetController.dispose();
    _shippingCityController.dispose();
    _shippingStateController.dispose();
    _shippingPostalCodeController.dispose();
    _shippingCountryController.dispose();
    _shippingPhoneController.dispose();
    _billingFullNameController.dispose();
    _billingStreetController.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPostalCodeController.dispose();
    _billingCountryController.dispose();
    _billingPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final userData = await _userService.getUserById(user.uid);
        final items = await _cartService.getCartItems(user.uid);
        setState(() {
          _currentUser = userData;
          _isLoggedIn = true;
          _cartItems = items;
          if (userData?.addresses.isNotEmpty == true) {
            _selectedShippingAddress = userData!.addresses.first;
            _selectedBillingAddress = userData.addresses.first;
          }
          _isLoading = false;
        });
      } else {
        final tempUser = _authService.currentUser;
        if (tempUser != null) {
          final items = await _cartService.getCartItems(tempUser.uid);
          setState(() {
            _cartItems = items;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _proceedToOrder() async {
    Address? shippingAddress;
    Address? billingAddress;

    if (_shippingMethod == 'collection') {
      // For collection orders, create a default address
      if (!_isLoggedIn && !_guestFormKey.currentState!.validate()) return;
      
      shippingAddress = Address(
        id: const Uuid().v4(),
        fullName: 'Collection at BimmerWise',
        street: 'Unit 5, Blake\'s Cross Business Park, Ballealy Lane',
        city: 'Lusk',
        state: 'Co. Dublin',
        postalCode: 'K45 X597',
        country: 'Ireland',
        phone: '+353852624258',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      billingAddress = shippingAddress;
    } else {
      // Standard shipping flow
      if (_isLoggedIn) {
        if (_useDifferentShippingAddress) {
          if (!_shippingFormKey.currentState!.validate()) return;
          shippingAddress = Address(
            id: const Uuid().v4(),
            fullName: _shippingFullNameController.text,
            street: _shippingStreetController.text,
            city: _shippingCityController.text,
            state: _shippingStateController.text,
            postalCode: _shippingPostalCodeController.text,
            country: _shippingCountryController.text,
            phone: _shippingPhoneController.text,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          shippingAddress = _selectedShippingAddress;
        }
        
        if (_useDifferentBillingAddress) {
          billingAddress = _selectedBillingAddress;
        } else {
          billingAddress = shippingAddress;
        }
      } else {
        if (!_guestFormKey.currentState!.validate()) return;
        if (!_shippingFormKey.currentState!.validate()) return;
        if (_useDifferentBillingAddress && !_billingFormKey.currentState!.validate()) return;
        
        shippingAddress = Address(
          id: const Uuid().v4(),
          fullName: _shippingFullNameController.text,
          street: _shippingStreetController.text,
          city: _shippingCityController.text,
          state: _shippingStateController.text,
          postalCode: _shippingPostalCodeController.text,
          country: _shippingCountryController.text,
          phone: _shippingPhoneController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (_useDifferentBillingAddress) {
          billingAddress = Address(
            id: const Uuid().v4(),
            fullName: _billingFullNameController.text,
            street: _billingStreetController.text,
            city: _billingCityController.text,
            state: _billingStateController.text,
            postalCode: _billingPostalCodeController.text,
            country: _billingCountryController.text,
            phone: _billingPhoneController.text,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } else {
          billingAddress = shippingAddress;
        }
      }

      if (shippingAddress == null || billingAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all required fields')),
        );
        return;
      }
    }

    try {
      final order = Order(
        id: const Uuid().v4(),
        userId: _isLoggedIn ? _currentUser!.id : 'guest',
        userName: _isLoggedIn ? _currentUser!.name : _guestNameController.text,
        userEmail: _isLoggedIn ? _currentUser!.email : _guestEmailController.text,
        userPhone: _isLoggedIn ? _currentUser!.phone : _guestPhoneController.text,
        items: _cartItems,
        shippingAddress: shippingAddress,
        billingAddress: billingAddress,
        shippingMethod: _shippingMethod,
        status: 'Pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _orderService.createOrder(order);
      
      if (_isLoggedIn) {
        await _cartService.clearCart(_currentUser!.id);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Order Placed Successfully!'),
            content: const Text('Thank you for your order. We will contact you soon for payment and delivery details.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001E50),
                  foregroundColor: Colors.white,
                ),
                child: const Text('GO HOME'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
      }
    }
  }

  Future<void> _openGoogleMaps() async {
    final Uri url = Uri.parse('https://www.google.com/maps/dir//Unit+5,+Bimmerwise,+Blake\'s+Cross+Business+Park,+Ballealy+Lane,+Newhaggard,+Lusk,+Co.+Dublin,+K45+X597,+Ireland/@53.4255634,-6.3855408,14z/data=!4m8!4m7!1m0!1m5!1m1!1s0x4867130e58f69cc1:0x7114ddc741b4fbda!2m2!1d-6.1846077!2d53.5034239?hl=en&authuser=0&entry=ttu&g_ep=EgoyMDI1MTIwOS4wIKXMDSoASAFQAw%3D%3D');
    if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF001E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF001E50)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isLoggedIn) ...[
                    _buildGuestInfoSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildShippingMethodSection(),
                  const SizedBox(height: 24),
                  if (_shippingMethod == 'standard') ...[
                    if (_isLoggedIn) _buildAddressSelectionSection() else _buildShippingAddressForm(),
                    const SizedBox(height: 16),
                    if (!_isLoggedIn) ...[
                      CheckboxListTile(
                        value: _useDifferentBillingAddress,
                        onChanged: (value) => setState(() => _useDifferentBillingAddress = value ?? false),
                        title: const Text('Use Different Billing Address'),
                        activeColor: const Color(0xFF001E50),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      if (_useDifferentBillingAddress) ...[
                        _buildBillingAddressForm(),
                        const SizedBox(height: 24),
                      ],
                    ],
                    if (_isLoggedIn) const SizedBox(height: 8),
                  ],
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _proceedToOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001E50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'PLACE ORDER',
                        style: context.textStyles.titleMedium?.bold.withColor(Colors.white),
                      ),
                    ),
                  ),
                  if (!_isLoggedIn) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/login?service=&category='),
                        child: const Text('Already have an account? Log in'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildGuestInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _guestFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Information', style: context.textStyles.titleMedium?.bold),
              const SizedBox(height: 16),
              TextFormField(
                controller: _guestNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guestPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingMethodSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipping Method', style: context.textStyles.titleMedium?.bold),
            const SizedBox(height: 16),
            RadioListTile<String>(
              value: 'standard',
              groupValue: _shippingMethod,
              onChanged: (value) => setState(() => _shippingMethod = value!),
              title: const Text('Standard Shipping'),
              subtitle: const Text('3-5 Working Days'),
              activeColor: const Color(0xFF001E50),
            ),
            RadioListTile<String>(
              value: 'collection',
              groupValue: _shippingMethod,
              onChanged: (value) => setState(() => _shippingMethod = value!),
              title: const Text('Collection at BimmerWise'),
              subtitle: const Text('Pick up from our location'),
              activeColor: const Color(0xFF001E50),
            ),
            if (_shippingMethod == 'collection') ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _openGoogleMaps,
                  icon: const Icon(Icons.directions),
                  label: const Text('GET DIRECTIONS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001E50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSelectionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipping Address', style: context.textStyles.titleMedium?.bold),
            const SizedBox(height: 16),
            if (_currentUser?.addresses.isNotEmpty == true) ...[
              DropdownButtonFormField<Address>(
                value: _selectedShippingAddress,
                decoration: const InputDecoration(
                  labelText: 'Select Address',
                  border: OutlineInputBorder(),
                ),
                items: _currentUser!.addresses.map((address) {
                  return DropdownMenuItem(
                    value: address,
                    child: Text(address.shortDisplay, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedShippingAddress = value),
              ),
              if (_selectedShippingAddress != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressDetailRow('Full Name', _selectedShippingAddress!.fullName),
                      _buildAddressDetailRow('Street', _selectedShippingAddress!.street),
                      _buildAddressDetailRow('City', _selectedShippingAddress!.city),
                      _buildAddressDetailRow('County', _selectedShippingAddress!.state),
                      _buildAddressDetailRow('Eircode', _selectedShippingAddress!.postalCode),
                      _buildAddressDetailRow('Country', _selectedShippingAddress!.country),
                      _buildAddressDetailRow('Phone', _selectedShippingAddress!.phone),
                    ],
                  ),
                ),
              ],
            ] else
              const Text('No saved addresses'),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _useDifferentShippingAddress,
              onChanged: (value) => setState(() => _useDifferentShippingAddress = value ?? false),
              title: const Text('Use different shipping address'),
              activeColor: const Color(0xFF001E50),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_useDifferentShippingAddress) ...[
              const SizedBox(height: 16),
              _buildShippingAddressForm(),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _useDifferentBillingAddress,
              onChanged: (value) => setState(() => _useDifferentBillingAddress = value ?? false),
              title: const Text('Use Different Billing Address'),
              activeColor: const Color(0xFF001E50),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_useDifferentBillingAddress) ...[
              const SizedBox(height: 24),
              Text('Billing Address', style: context.textStyles.titleMedium?.bold),
              const SizedBox(height: 16),
              if (_currentUser?.addresses.isNotEmpty == true) ...[
              DropdownButtonFormField<Address>(
                value: _selectedBillingAddress,
                decoration: const InputDecoration(
                  labelText: 'Select Address',
                  border: OutlineInputBorder(),
                ),
                items: _currentUser!.addresses.map((address) {
                  return DropdownMenuItem(
                    value: address,
                    child: Text(address.shortDisplay, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedBillingAddress = value),
              ),
              if (_selectedBillingAddress != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressDetailRow('Full Name', _selectedBillingAddress!.fullName),
                      _buildAddressDetailRow('Street', _selectedBillingAddress!.street),
                      _buildAddressDetailRow('City', _selectedBillingAddress!.city),
                      _buildAddressDetailRow('County', _selectedBillingAddress!.state),
                      _buildAddressDetailRow('Eircode', _selectedBillingAddress!.postalCode),
                      _buildAddressDetailRow('Country', _selectedBillingAddress!.country),
                      _buildAddressDetailRow('Phone', _selectedBillingAddress!.phone),
                    ],
                  ),
                ),
              ],
            ] else
              const Text('No saved addresses'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShippingAddressForm() {
    final formContent = Form(
      key: _shippingFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isLoggedIn) Text('Shipping Address', style: context.textStyles.titleMedium?.bold),
          if (!_isLoggedIn) const SizedBox(height: 16),
          TextFormField(
            controller: _shippingFullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (value) => value?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shippingStreetController,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (value) => value?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _shippingCityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: _shippingStateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _shippingPostalCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: _shippingCountryController,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shippingPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) => value?.isEmpty == true ? 'Required' : null,
          ),
        ],
      ),
    );

    if (!_isLoggedIn) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: formContent,
        ),
      );
    }
    return formContent;
  }

  Widget _buildBillingAddressForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Form(
          key: _billingFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Billing Address', style: context.textStyles.titleMedium?.bold),
              const SizedBox(height: 16),
              TextFormField(
                controller: _billingFullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _billingStreetController,
                decoration: const InputDecoration(
                  labelText: 'Street Address',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _billingCityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      controller: _billingStateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _billingPostalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      controller: _billingCountryController,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _billingPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary', style: context.textStyles.titleMedium?.bold),
            const SizedBox(height: 16),
            ..._cartItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName} (${item.variantName}) x ${item.quantity}',
                      style: context.textStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Items', style: context.textStyles.titleSmall?.bold),
                Text(
                  '${_cartItems.fold(0, (sum, item) => sum + item.quantity)}',
                  style: context.textStyles.titleSmall?.bold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
