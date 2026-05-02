import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../core/constants/app_colors.dart';

const Color _offSaleColor = Color(0xFF7AAF91);

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onEdit;
  final VoidCallback? onOrder;
  final VoidCallback? onSelect;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final int quantity;
  final bool isBusiness;
  final bool isSelected;
  final bool isService;

  const ProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onOrder,
    this.onSelect,
    this.onAdd,
    this.onRemove,
    this.quantity = 0,
    this.isBusiness = false,
    this.isSelected = false,
    this.isService = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _selectController;
  late Animation<double> _selectAnimation;

  @override
  void initState() {
    super.initState();
    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _selectAnimation = CurvedAnimation(
      parent: _selectController,
      curve: Curves.easeOutBack,
    );
    if (widget.isSelected) _selectController.forward();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectController.forward();
      } else {
        _selectController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _selectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _selectAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      AppColors.card,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.glassBorder,
              width: widget.isSelected ? 1.5 : 0.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Selected indicator
                if (widget.isSelected)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, val, child) {
                      return Transform.scale(scale: val, child: child);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.product.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    decoration: widget.product.isOffSale
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: widget.product.isOffSale
                                        ? AppColors.textHint
                                        : widget.isSelected
                                            ? AppColors.primaryLight
                                            : null,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (widget.product.isOffSale) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(widget.isBusiness ? 'OFF SALE' : 'OFF SALE', _offSaleColor),
                          ] else if (widget.product.isOutOfStock) ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge('OUT OF STOCK', AppColors.warning),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.product.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.product.isOffSale && !widget.isBusiness) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Visible but unavailable for ordering',
                          style: TextStyle(color: _offSaleColor, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                      if (widget.product.durationMinutes > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timelapse_rounded, size: 13, color: AppColors.primaryLight),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.product.durationMinutes} min',
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Price tag with gradient background
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (widget.isSelected ? AppColors.primary : AppColors.secondary)
                                  .withValues(alpha: 0.12),
                              (widget.isSelected ? AppColors.primary : AppColors.secondary)
                                  .withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '\$${widget.product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: widget.isSelected
                                ? AppColors.primaryLight
                                : AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.isBusiness && !widget.isService) ...[
                      // Stock indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 12,
                              color: widget.product.stock > 5
                                  ? AppColors.secondary
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.product.stock}',
                              style: TextStyle(
                                color: widget.product.stock > 5
                                    ? AppColors.secondary
                                    : AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onEdit != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                            onPressed: widget.onEdit,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ] else if (widget.isBusiness && widget.isService && widget.onEdit != null) ...[
                      // Allow edit for service but hide stock
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                          onPressed: widget.onEdit,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ] else if (widget.onAdd != null) ...[
                      // Inline quantity stepper for queue
                      Container(
                        decoration: BoxDecoration(
                          color: widget.quantity > 0 ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.quantity > 0 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.quantity > 0) ...[
                              InkWell(
                                onTap: (widget.product.isOutOfStock || widget.product.isOffSale) ? null : widget.onRemove,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Icon(Icons.remove_rounded, size: 16, color: AppColors.primary),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '${widget.quantity}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                ),
                              ),
                            ],
                            InkWell(
                              onTap: (widget.product.isOutOfStock || widget.product.isOffSale) ? null : widget.onAdd,
                              borderRadius: widget.quantity > 0
                                  ? const BorderRadius.horizontal(right: Radius.circular(12))
                                  : BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: widget.quantity == 0
                                    ? Text(
                                        widget.product.isOffSale ? 'Off sale' : 'Add',
                                        style: TextStyle(
                                          color: (widget.product.isOutOfStock || widget.product.isOffSale) ? AppColors.textHint : AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (widget.onOrder != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          gradient: widget.isSelected ? AppColors.primaryGradient : null,
                          color: widget.isSelected ? null : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: widget.isSelected
                              ? null
                              : Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: (widget.product.isOutOfStock || widget.product.isOffSale)
                                ? null
                                : widget.onOrder,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Text(
                                widget.product.isOffSale
                                    ? 'Off sale'
                                    : (widget.isSelected ? 'Selected' : (widget.isService ? 'Book' : 'Select')),
                                style: TextStyle(
                                  color: widget.isSelected && !widget.product.isOffSale ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
