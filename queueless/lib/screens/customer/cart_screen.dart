import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/credit_card_widget.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _validatingCoupon = false;
  String? _couponError;
  Map<String, dynamic>? _appliedDiscount;
  List<Map<String, dynamic>> _availableCoupons = [];
  bool _loadingCoupons = false;
  String? _loadedCouponBusinessId;
  String _paymentMethod = 'later'; // 'now' or 'later'
  Map<String, String>? _cardData; // filled when pay now is confirmed

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _validateCoupon(CartProvider cart) async {
    if (_couponController.text.trim().isEmpty) return;
    if (cart.businessId == null) return;

    setState(() { _validatingCoupon = true; _couponError = null; _appliedDiscount = null; });
    try {
      final result = await ApiService.post('/discounts/validate', {
        'businessId': cart.businessId,
        'code': _couponController.text.trim().toUpperCase(),
        'amount': cart.totalAmount,
      });
      setState(() { _appliedDiscount = result; });
    } catch (e) {
      setState(() { _couponError = 'Invalid or expired coupon code'; });
    } finally {
      setState(() { _validatingCoupon = false; });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedDiscount = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  void _ensureCouponsLoaded(String? businessId) {
    if (businessId == null || businessId.isEmpty) return;
    if (_loadedCouponBusinessId == businessId || _loadingCoupons) return;
    _loadedCouponBusinessId = businessId;
    _loadCoupons(businessId);
  }

  Future<void> _loadCoupons(String businessId) async {
    setState(() {
      _loadingCoupons = true;
      _availableCoupons = [];
    });

    try {
      final result = await ApiService.get('/discounts?businessId=$businessId');
      if (!mounted) return;
      setState(() {
        _availableCoupons = (result as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableCoupons = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingCoupons = false;
      });
    }
  }

  String _cleanError(String msg) {
    return msg.replaceAll(RegExp(r'^Exception:\s*'), '').replaceAll(RegExp(r'^Error:\s*'), '');
  }

  double _couponValue(Map<String, dynamic> coupon) {
    final raw = coupon['value'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _couponLabel(Map<String, dynamic> coupon) {
    final value = _couponValue(coupon);
    return coupon['type'] == 'percentage'
        ? '${value.toStringAsFixed(0)}% off'
      : '\$${value.toStringAsFixed(2)} off';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Basket'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          _ensureCouponsLoaded(cart.businessId);

          if (cart.items.isEmpty) {
            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Opacity(opacity: val, child: Transform.translate(
                    offset: Offset(0, 20 * (1 - val)), child: child,
                  ));
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.surfaceLight, AppColors.surface]),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: const Icon(Icons.shopping_basket_outlined, size: 56, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 24),
                    const Text('Your basket is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Add items from the business page', style: TextStyle(color: AppColors.textHint)),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items.values.toList()[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (index * 60)),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, child) {
                        return Opacity(opacity: val, child: Transform.translate(
                          offset: Offset(0, 16 * (1 - val)), child: child,
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.cardGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '\$${item.product.price.toStringAsFixed(2)} each',
                                      style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity controls
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.glassBorder, width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QuantityButton(
                                    icon: Icons.remove_rounded,
                                    color: AppColors.error,
                                    onTap: () {
                                      if (_appliedDiscount != null) _removeCoupon();
                                      cart.removeSingleItem(item.product.id);
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  _QuantityButton(
                                    icon: Icons.add_rounded,
                                    color: AppColors.primary,
                                    onTap: () {
                                      if (_appliedDiscount != null) _removeCoupon();
                                      cart.addItem(item.product);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomSummary(context, cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomSummary(BuildContext context, CartProvider cart) {
    final discountAmount = (_appliedDiscount != null)
        ? ((_appliedDiscount!['discount_amount'] as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final finalAmount = cart.totalAmount - discountAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5), width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coupon code field
            if (_loadingCoupons || _availableCoupons.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Available coupons',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingCoupons)
                const LinearProgressIndicator(minHeight: 2, color: AppColors.primary)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableCoupons.map((coupon) {
                    final code = coupon['code']?.toString() ?? '';
                    return ActionChip(
                      label: Text('$code  •  ${_couponLabel(coupon)}'),
                      backgroundColor: AppColors.surfaceLight,
                      side: BorderSide(color: AppColors.glassBorder.withValues(alpha: 0.8)),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      onPressed: _validatingCoupon
                          ? null
                          : () {
                              setState(() {
                                _couponController.text = code;
                              });
                              _validateCoupon(cart);
                            },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Coupon code',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.textHint),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: _appliedDiscount != null
                          ? IconButton(
                              onPressed: _removeCoupon,
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                            )
                          : null,
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    enabled: _appliedDiscount == null,
                  ),
                ),
                const SizedBox(width: 10),
                _appliedDiscount == null
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: _validatingCoupon ? null : () => _validateCoupon(cart),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _validatingCoupon
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(_couponError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            if (_appliedDiscount != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_couponController.text.trim().toUpperCase()} applied — -\$${discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Total row
            if (discountAmount > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                  Text('\$${cart.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: TextStyle(fontSize: 14, color: AppColors.success)),
                  Text('-\$${discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 16, color: AppColors.textHint)),
                ShaderMask(
                  shaderCallback: (bounds) => AppColors.heroGradient.createShader(bounds),
                  child: Text(
                    '\$${finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Payment method
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Method', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _paymentMethod = 'later'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'later' ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _paymentMethod == 'later' ? AppColors.primary : AppColors.glassBorder,
                              width: _paymentMethod == 'later' ? 1.5 : 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.store_rounded, size: 20, color: _paymentMethod == 'later' ? AppColors.primary : AppColors.textHint),
                              const SizedBox(height: 4),
                              Text('Pay on Arrival', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _paymentMethod == 'later' ? AppColors.primary : AppColors.textHint)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final card = await showCreditCardSheet(context);
                          if (card != null && mounted) {
                            setState(() {
                              _paymentMethod = 'now';
                              _cardData = card;
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _paymentMethod == 'now' ? AppColors.secondary.withValues(alpha: 0.12) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _paymentMethod == 'now' ? AppColors.secondary : AppColors.glassBorder,
                              width: _paymentMethod == 'now' ? 1.5 : 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _cardData != null ? Icons.check_circle_rounded : Icons.credit_card_rounded,
                                size: 20,
                                color: _paymentMethod == 'now' ? AppColors.secondary : AppColors.textHint,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _cardData != null ? 'Card Added ✓' : 'Pay Now',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _paymentMethod == 'now' ? AppColors.secondary : AppColors.textHint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _paymentMethod == 'later' ? 'You will pay when you arrive at the venue.' : 'Payment will be processed after confirming.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final qProvider = Provider.of<QueueProvider>(context, listen: false);

                  if (auth.currentUser != null) {
                    if (_paymentMethod == 'now' && _cardData == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Add a card before choosing card payment.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    try {
                      final notes = _appliedDiscount != null
                          ? '${cart.cartSummary} | Coupon: ${_couponController.text.trim().toUpperCase()}'
                          : cart.cartSummary;
                      final discountAmt = _appliedDiscount != null
                          ? ((_appliedDiscount!['discount_amount'] as num?) ?? 0).toDouble()
                          : 0.0;
                      final discountCode = _appliedDiscount != null ? _couponController.text.trim().toUpperCase() : null;
                      await qProvider.joinQueue(
                        cart.businessId!,
                        notes: notes,
                        items: cart.queueItems,
                        totalPrice: _appliedDiscount != null
                            ? ((_appliedDiscount!['final_amount'] as num?) ?? cart.totalAmount).toDouble()
                            : cart.totalAmount,
                        paymentMethod: _paymentMethod,
                        discountCode: discountCode,
                        discountAmount: discountAmt,
                      );

                      if (context.mounted) {
                        cart.clearCart();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Joined queue successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_cleanError(e.toString())), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Confirm & Join Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
