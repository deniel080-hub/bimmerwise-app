import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/product_service.dart';
import 'package:bimmerwise_connect/services/cart_service.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/models/product_model.dart';
import 'package:bimmerwise_connect/models/cart_item_model.dart';
import 'package:uuid/uuid.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  Product? _product;
  bool _isLoading = true;
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _loadCartCount();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final product = await _productService.getProductById(widget.productId);
      setState(() {
        _product = product;
        _selectedVariant = product?.variants.isNotEmpty == true ? product!.variants.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product: $e')),
        );
      }
    }
  }

  Future<void> _loadCartCount() async {
    final user = _authService.currentUser;
    if (user != null) {
      final count = await _cartService.getCartItemCount(user.uid);
      setState(() => _cartItemCount = count);
    }
  }

  Future<void> _addToCart() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to cart')),
      );
      context.push('/login?service=&category=');
      return;
    }

    if (_product == null || _selectedVariant == null) return;

    if (_selectedVariant!.stock < _quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough stock available')),
      );
      return;
    }

    try {
      final cartItem = CartItem(
        id: '${_product!.id}_${_selectedVariant!.id}',
        productId: _product!.id,
        productName: _product!.name,
        variantId: _selectedVariant!.id,
        variantName: _selectedVariant!.name,
        variantImageUrl: _selectedVariant!.imageUrl,
        quantity: _quantity,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _cartService.addToCart(user.uid, cartItem);
      await _loadCartCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cart: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF001E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () async {
                  await context.push('/cart');
                  _loadCartCount();
                },
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _cartItemCount > 9 ? '9+' : '$_cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF001E50)))
          : _product == null
              ? const Center(child: Text('Product not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedVariant != null)
                        Image.asset(
                          _selectedVariant!.imageUrl,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 300,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported, size: 60),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _product!.name,
                              style: context.textStyles.headlineSmall?.bold,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select Variant',
                              style: context.textStyles.titleMedium?.bold,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _product!.variants.map((variant) {
                                final isSelected = _selectedVariant?.id == variant.id;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedVariant = variant),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF001E50) : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF001E50) : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          variant.name,
                                          style: context.textStyles.bodyMedium?.bold.withColor(
                                            isSelected ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: ${variant.stock}',
                                          style: context.textStyles.bodySmall?.withColor(
                                            isSelected ? Colors.white70 : Colors.grey[600]!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Text(
                                  'Quantity',
                                  style: context.textStyles.titleMedium?.bold,
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: const Color(0xFF001E50),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_quantity',
                                    style: context.textStyles.titleMedium?.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _selectedVariant != null && _quantity < _selectedVariant!.stock
                                      ? () => setState(() => _quantity++)
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: const Color(0xFF001E50),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _product!.note,
                              style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Details',
                              style: context.textStyles.titleMedium?.bold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _product!.description,
                              style: context.textStyles.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Compatibility',
                              style: context.textStyles.titleMedium?.bold,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _product!.compatibility,
                              style: context.textStyles.bodyMedium,
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _selectedVariant?.stock != null && _selectedVariant!.stock > 0
                                    ? _addToCart
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF001E50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: Colors.grey[400],
                                ),
                                child: Text(
                                  _selectedVariant?.stock != null && _selectedVariant!.stock > 0
                                      ? 'ADD TO CART'
                                      : 'OUT OF STOCK',
                                  style: context.textStyles.titleMedium?.bold.withColor(Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
