import 'package:flutter/material.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/product_service.dart';
import 'package:bimmerwise_connect/models/product_model.dart';
import 'package:uuid/uuid.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<void> _updateVariantStock(Product product, ProductVariant variant) async {
    final controller = TextEditingController(text: variant.stock.toString());
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock: ${variant.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text);
              if (newStock != null) {
                Navigator.of(context).pop(newStock);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _productService.updateVariantStock(product.id, variant.id, result);
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock updated for ${variant.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating stock: $e')),
          );
        }
      }
    }
  }

  Future<void> _initializeBMWProduct() async {
    try {
      final product = Product(
        id: const Uuid().v4(),
        name: 'BMW LED Door Projectors',
        category: 'Accessories',
        description: 'BMW LED Door Logo Projector\n\n'
            'Premium LED door light that projects the BMW logo onto the ground when the door is opened. '
            'Enhances vehicle appearance, improves visibility in low light, and provides a refined welcome effect. '
            'Plug-and-play fitment with OEM-style finish.',
        compatibility: 'Suitable for most BMW models equipped with factory door courtesy lights.\n'
            'Please ensure your vehicle is already fitted with standard door lights before purchase.',
        variants: [
          ProductVariant(
            id: 'bmw_logo',
            name: 'BMW Logo',
            imageUrl: 'assets/images/bmwlogo.jpg',
            stock: 10,
          ),
          ProductVariant(
            id: 'm_logo',
            name: 'M Logo',
            imageUrl: 'assets/images/Mlogo.jpg',
            stock: 10,
          ),
          ProductVariant(
            id: 'm_power',
            name: 'M Power',
            imageUrl: 'assets/images/mpowerlogo.jpg',
            stock: 10,
          ),
        ],
        note: '1 box includes 1 pair of lights',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _productService.addProduct(product);
      await _loadProducts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BMW LED Door Projectors product initialized!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF001E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
          if (_products.isEmpty)
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _initializeBMWProduct,
              tooltip: 'Initialize BMW Product',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF001E50)))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No products yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _initializeBMWProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Initialize BMW LED Door Projectors'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001E50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            product.variants.isNotEmpty
                                ? product.variants.first.imageUrl
                                : 'assets/images/bmwlogo.jpg',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: context.textStyles.titleMedium?.bold,
                        ),
                        subtitle: Text(
                          '${product.variants.length} variants',
                          style: context.textStyles.bodySmall,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Variants & Stock',
                                  style: context.textStyles.titleSmall?.bold,
                                ),
                                const SizedBox(height: 12),
                                ...product.variants.map((variant) => Card(
                                      color: Colors.grey[100],
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.asset(
                                            variant.imageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Container(
                                              width: 50,
                                              height: 50,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.image_not_supported),
                                            ),
                                          ),
                                        ),
                                        title: Text(variant.name),
                                        subtitle: Text(
                                          'Stock: ${variant.stock}',
                                          style: TextStyle(
                                            color: variant.stock > 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFF001E50)),
                                          onPressed: () =>
                                              _updateVariantStock(product, variant),
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
