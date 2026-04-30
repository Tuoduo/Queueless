import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/discount_model.dart';
import '../../../providers/discount_provider.dart';

class DiscountManagementScreen extends StatefulWidget {
  final String businessId;
  const DiscountManagementScreen({super.key, required this.businessId});

  @override
  State<DiscountManagementScreen> createState() => _DiscountManagementScreenState();
}

class _DiscountManagementScreenState extends State<DiscountManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscountProvider>().loadMyDiscounts();
    });
  }

  void _showCreateDialog() {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    String selectedType = 'percentage';
    int maxUsage = 1;
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Create Coupon', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogField(codeController, 'Coupon Code (e.g. SAVE20)', Icons.local_offer_outlined),
                    const SizedBox(height: 12),
                    _dialogField(valueController, 'Value', Icons.attach_money_outlined,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          dropdownColor: AppColors.surface,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                            DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (\$)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => selectedType = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 18, color: AppColors.textHint),
                          const SizedBox(width: 8),
                          const Text('Max Uses:', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: maxUsage > 1 ? () => setDialogState(() => maxUsage--) : null,
                          ),
                          Text(maxUsage.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => setDialogState(() => maxUsage++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => expiresAt = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 18, color: AppColors.textHint),
                            const SizedBox(width: 8),
                            Text(
                              expiresAt != null
                                  ? 'Expires: ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}'
                                  : 'Set Expiry Date (Optional)',
                              style: TextStyle(
                                color: expiresAt != null ? AppColors.textPrimary : AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                            if (expiresAt != null) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setDialogState(() => expiresAt = null),
                                child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textHint),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final code = codeController.text.trim().toUpperCase();
                    final val = double.tryParse(valueController.text.trim());
                    if (code.isEmpty || val == null || val <= 0) return;

                    try {
                      await context.read<DiscountProvider>().createDiscount(
                        code: code,
                        type: selectedType,
                        value: val,
                        maxUsageCount: maxUsage,
                        expiresAt: expiresAt,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogField(TextEditingController c, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Discount Coupons', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Coupon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Consumer<DiscountProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.error != null && provider.myDiscounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Coupons could not be loaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => context.read<DiscountProvider>().loadMyDiscounts(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.myDiscounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_offer_outlined, size: 48, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 20),
                  const Text('No Coupons Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap + to create your first discount coupon',
                      style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: provider.myDiscounts.length,
            itemBuilder: (context, index) {
              final discount = provider.myDiscounts[index];
              return _buildDiscountCard(discount, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildDiscountCard(DiscountModel discount, DiscountProvider provider) {
    final isExpired = discount.expiresAt != null && discount.expiresAt!.isBefore(DateTime.now());
    final isExhausted = discount.usedCount >= discount.maxUsageCount;
    final effectivelyActive = discount.isActive && !isExpired && !isExhausted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectivelyActive ? AppColors.primary.withOpacity(0.2) : AppColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: effectivelyActive
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    discount.code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1.5,
                      color: effectivelyActive ? AppColors.primaryLight : AppColors.textHint,
                    ),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: discount.isActive,
                  onChanged: (_) => provider.toggleDiscount(discount.id),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(
                  Icons.discount_rounded,
                  discount.type == 'percentage'
                      ? '${discount.value.toStringAsFixed(0)}% off'
                      : '₺${discount.value.toStringAsFixed(2)} off',
                  AppColors.secondary,
                ),
                const SizedBox(width: 8),
                _infoChip(
                  Icons.people_outline_rounded,
                  '${discount.usedCount}/${discount.maxUsageCount} used',
                  AppColors.primary,
                ),
                if (discount.expiresAt != null) ...[
                  const SizedBox(width: 8),
                  _infoChip(
                    Icons.event_outlined,
                    '${discount.expiresAt!.day}/${discount.expiresAt!.month}/${discount.expiresAt!.year}',
                    isExpired ? AppColors.error : AppColors.textHint,
                  ),
                ],
              ],
            ),
            if (!effectivelyActive) ...[
              const SizedBox(height: 8),
              Text(
                isExpired ? 'Expired' : isExhausted ? 'Fully Used' : 'Inactive',
                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Delete Coupon?'),
                      content: Text('Are you sure you want to delete coupon "${discount.code}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await provider.deleteDiscount(discount.id);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                label: const Text('Delete', style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
