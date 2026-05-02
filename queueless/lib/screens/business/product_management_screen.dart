import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/product_provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/custom_text_field.dart';

class ProductManagementScreen extends StatefulWidget {
  final bool isService;
  const ProductManagementScreen({super.key, this.isService = false});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
        final business = businessProvider.getBusinessByOwnerId(auth.currentUser!.id);
        if (business != null) {
          Provider.of<ProductProvider>(context, listen: false).loadBusinessProducts(business.id, all: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddProductForm(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          if (productProvider.isLoading && productProvider.products.isEmpty) {
            return LoadingWidget(message: widget.isService ? 'Loading services...' : 'Loading products...');
          }

          if (productProvider.error != null) {
            return Center(child: Text('Error: ${productProvider.error}'));
          }

          final products = productProvider.products;

          if (products.isEmpty) {
            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Opacity(opacity: val, child: Transform.translate(
                    offset: Offset(0, 24 * (1 - val)), child: child,
                  ));
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (context, val, child) => Transform.scale(scale: val, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.surfaceLight, AppColors.surface]),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: Icon(
                          widget.isService ? Icons.design_services_outlined : Icons.inventory_2_outlined,
                          size: 52,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.isService ? 'No services found' : 'No products found',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isService ? 'Add your first service.' : 'Add your first product.',
                      style: const TextStyle(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
              final business = businessProvider.getBusinessByOwnerId(auth.currentUser?.id ?? '');
              if (business != null) {
                await productProvider.loadBusinessProducts(business.id, all: true);
              }
            },
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 60)),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Opacity(opacity: val, child: Transform.translate(
                      offset: Offset(0, 16 * (1 - val)), child: child,
                    ));
                  },
                  child: ProductCard(
                    product: product,
                    isBusiness: true,
                    isService: widget.isService,
                    onEdit: () {
                      _showEditProductDialog(context, productProvider, product);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddProductForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final durationController = TextEditingController(text: '0');
    final costController = TextEditingController(text: '0.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            left: BorderSide(color: AppColors.glassBorder, width: 0.5),
            right: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -10)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.isService ? Icons.design_services_rounded : Icons.add_shopping_cart_rounded,
                        color: Colors.white, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isService ? 'Add New Service' : 'Add New Product',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: nameController,
                  labelText: 'Name',
                  prefixIcon: Icons.shopping_bag_outlined,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: descController,
                  labelText: 'Description',
                  prefixIcon: Icons.description_outlined,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: priceController,
                        labelText: 'Price (\$)',
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    if (!widget.isService) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          controller: stockController,
                          labelText: 'Initial Stock',
                          prefixIcon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (!widget.isService) ...[
                CustomTextField(
                  controller: durationController,
                  labelText: 'Service Duration (min, 0 = auto)',
                  prefixIcon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (int.tryParse(v) == null || int.parse(v) < 0) return 'Enter 0 or a positive number';
                    return null;
                  },
                ),
                ],
                const SizedBox(height: 16),
                CustomTextField(
                  controller: costController,
                  labelText: 'Net Cost (\$)',
                  prefixIcon: Icons.money_off_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v) == null || double.parse(v) < 0) return 'Enter a valid cost';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final provider = Provider.of<ProductProvider>(context, listen: false);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
                        final business = businessProvider.getBusinessByOwnerId(auth.currentUser?.id ?? '');

                        if (business == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not find your business profile.'), backgroundColor: AppColors.error),
                            );
                          }
                          return;
                        }

                        try {
                          await provider.addProduct(
                            businessId: business.id,
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            price: double.parse(priceController.text),
                            stock: widget.isService ? 0 : int.parse(stockController.text),
                            durationMinutes: widget.isService ? 0 : (int.tryParse(durationController.text) ?? 0),
                            cost: double.tryParse(costController.text) ?? 0,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(widget.isService ? 'Service added' : 'Product added')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.isService ? 'Add Service' : 'Add Product', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(width: 8),
                        const Icon(Icons.add_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, ProductProvider provider, ProductModel product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final descController = TextEditingController(text: product.description);
    final priceController = TextEditingController(text: product.price.toStringAsFixed(2));
    final stockController = TextEditingController(text: product.stock.toString());
    final durationController = TextEditingController(text: product.durationMinutes.toString());
    final costController = TextEditingController(text: product.cost.toStringAsFixed(2));
    var isOffSale = product.isOffSale;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
            left: BorderSide(color: AppColors.glassBorder, width: 0.5),
            right: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.textHint.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Edit ${widget.isService ? "Service" : "Product"}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.glassWhite, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.close_rounded, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CustomTextField(controller: nameController, labelText: 'Name', prefixIcon: Icons.shopping_bag_outlined,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                CustomTextField(controller: descController, labelText: 'Description', prefixIcon: Icons.description_outlined,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(controller: priceController, labelText: 'Price (\$)', prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        }),
                    ),
                    if (!widget.isService) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(controller: stockController, labelText: 'Stock', prefixIcon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (int.tryParse(v) == null) return 'Invalid';
                            return null;
                          }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!widget.isService) ...[
                    Expanded(
                      child: CustomTextField(controller: durationController, labelText: 'Duration (min)', prefixIcon: Icons.timer_outlined,
                        keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: CustomTextField(controller: costController, labelText: 'Cost (\$)', prefixIcon: Icons.money_off_outlined,
                        keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInnerState) {
                    return SwitchListTile.adaptive(
                      value: isOffSale,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF7AAF91),
                      activeTrackColor: const Color(0xFFDDEFE3),
                      inactiveThumbColor: const Color(0xFFF4F8F5),
                      inactiveTrackColor: const Color(0xFFDDE7E1),
                      title: const Text('Off sale'),
                      subtitle: const Text('Customers will see this item as unavailable and cannot add it.'),
                      onChanged: (value) => setInnerState(() => isOffSale = value),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          await provider.updateProduct(
                            productId: product.id,
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            price: double.parse(priceController.text),
                            stock: int.tryParse(stockController.text) ?? product.stock,
                            durationMinutes: int.tryParse(durationController.text) ?? product.durationMinutes,
                            cost: double.tryParse(costController.text) ?? 0,
                            isOffSale: isOffSale,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(widget.isService ? 'Service updated' : 'Product updated')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete?'),
                        content: Text('Are you sure you want to delete "${product.name}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        await provider.deleteProduct(product.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${product.name}" deleted')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
