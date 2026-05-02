import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final bool isActive;

  const PurchaseHistoryScreen({super.key, this.isActive = false});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  final Map<String, int> _pendingStars = {};
  final Map<String, TextEditingController> _commentCtrl = {};
  final Map<String, bool> _submitting = {};
  final Map<String, bool> _editingRating = {};

  Timer? _timer;
  bool _fetchInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setup();
      _load(showSpinner: true);
    });
  }

  @override
  void didUpdateWidget(PurchaseHistoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      _scheduleTimer();
      if (widget.isActive) _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    SocketService().offHistoryUpdate();
    for (final c in _commentCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setup() {
    final userId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    final sock = SocketService();
    sock.connect();
    if (userId.isNotEmpty) sock.joinUser(userId);
    sock.offHistoryUpdate();
    sock.onHistoryUpdate((_) => _load());
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    if (!widget.isActive) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load({bool showSpinner = false}) async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;

    if (showSpinner && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final raw = await ApiService.get('/history');
      final list = (raw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_entries.isEmpty) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
        });
      } else {
        setState(() => _loading = false);
      }
    } finally {
      _fetchInProgress = false;
    }
  }

  TextEditingController _ctrl(String entryId) =>
      _commentCtrl.putIfAbsent(entryId, TextEditingController.new);

  Future<void> _submitRating(String entryId, String entryType, String businessId, String businessName) async {
    final stars = _pendingStars[entryId] ?? 0;
    if (stars == 0) return;
    if (_submitting[entryId] == true) return;

    setState(() => _submitting[entryId] = true);

    try {
      final comment = _ctrl(entryId).text.trim();
      final body = <String, dynamic>{
        'rating': stars,
        'entry_id': entryId,
        'entry_type': entryType,
      };
      if (comment.isNotEmpty) body['comment'] = comment;

      await ApiService.post('/businesses/$businessId/rating', body);

      if (!mounted) return;
      setState(() {
        // Update only the specific entry that was rated
        for (final e in _entries) {
          if ((e['id']?.toString() ?? '') == entryId) {
            e['user_rating'] = stars;
            e['user_comment'] = comment.isEmpty ? null : comment;
            break;
          }
        }
        _editingRating.remove(entryId);
        _pendingStars.remove(entryId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted for $businessName!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting.remove(entryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading your purchases...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.wifi_tethering_error_rounded,
                title: 'Could not load history',
                subtitle: _error!,
                onRetry: () => _load(showSpinner: true),
              ),
            )
          else if (_entries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No purchases yet',
                subtitle: 'When a business marks your order as done it will appear here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final e = _entries[i];
                    final eId = (e['id'] ?? '').toString();
                    return _EntryCard(
                      entry: e,
                      pendingStars: _pendingStars,
                      commentCtrl: _ctrl,
                      isSubmitting: _submitting[eId] ?? false,
                      isEditingRating: _editingRating[eId] ?? false,
                      onStarTap: (eId, s) => setState(() => _pendingStars[eId] = s),
                      onSubmit: _submitRating,
                      onEditRating: (eId) {
                        setState(() {
                          _editingRating[eId] = true;
                          final existing = int.tryParse(
                                  (_entries.firstWhere(
                                    (en) => (en['id']?.toString() ?? '') == eId,
                                    orElse: () => {},
                                  )['user_rating'] ?? '0')
                                      .toString()) ??
                              0;
                          _pendingStars[eId] = existing;
                        });
                      },
                    );
                  },
                  childCount: _entries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Purchase History',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _loading
                        ? 'Loading...'
                        : '${_entries.length} completed purchase${_entries.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Map<String, int> pendingStars;
  final TextEditingController Function(String) commentCtrl;
  final bool isSubmitting;
  final bool isEditingRating;
  final void Function(String, int) onStarTap;
  final Future<void> Function(String, String, String, String) onSubmit;
  final void Function(String) onEditRating;

  const _EntryCard({
    required this.entry,
    required this.pendingStars,
    required this.commentCtrl,
    required this.isSubmitting,
    required this.isEditingRating,
    required this.onStarTap,
    required this.onSubmit,
    required this.onEditRating,
  });

  @override
  Widget build(BuildContext context) {
    final type = (entry['type'] ?? '').toString();
    final isQueue = type == 'queue';
    final entryId = (entry['id'] ?? '').toString();
    final businessId = (entry['business_id'] ?? '').toString();
    final businessName = (entry['business_name'] ?? 'Business').toString();
    final serviceName =
        (entry['service_name'] ?? (isQueue ? 'Queue order' : 'Appointment'))
            .toString();
    final finalPrice =
        double.tryParse((entry['final_price'] ?? 0).toString()) ?? 0.0;
    final originalPrice =
        double.tryParse((entry['original_price'] ?? 0).toString()) ?? 0.0;
    final discountAmount =
        double.tryParse((entry['discount_amount'] ?? 0).toString()) ?? 0.0;
    final discountCode = (entry['discount_code'] ?? '').toString();
    final completedAt = entry['completed_at'] != null
        ? DateTime.tryParse(entry['completed_at'].toString())
        : null;
    final existingRating =
        int.tryParse((entry['user_rating'] ?? '0').toString()) ?? 0;
    final existingComment = (entry['user_comment'] ?? '').toString().trim();

    final typeColor = isQueue ? AppColors.primary : AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isQueue
                        ? Icons.shopping_basket_rounded
                        : Icons.calendar_month_rounded,
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(serviceName,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      if (completedAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 13, color: AppColors.textHint),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('d MMM yyyy • HH:mm')
                                  .format(completedAt),
                              style: const TextStyle(
                                  color: AppColors.textHint, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isQueue ? 'QUEUE' : 'APPT',
                    style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // price row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Text('Total paid',
                    style: TextStyle(
                        color: AppColors.textHint, fontSize: 13)),
                const Spacer(),
                if (discountAmount > 0 && originalPrice > finalPrice) ...[
                  Text(
                    '\$${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '\$${finalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // coupon badge
          if (discountCode.isNotEmpty && discountAmount > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        size: 13, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Coupon $discountCode saved \$${discountAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: AppColors.glassBorder),

          // rating section
          Padding(
            padding: const EdgeInsets.all(16),
            child: (existingRating > 0 && !isEditingRating)
                ? _RatedDisplay(
                    rating: existingRating,
                    comment: existingComment,
                    onEdit: () => onEditRating(entryId),
                  )
                : _RatingInput(
                    entryId: entryId,
                    entryType: type,
                    businessId: businessId,
                    businessName: businessName,
                    stars: pendingStars[entryId] ?? existingRating,
                    controller: commentCtrl(entryId),
                    isSubmitting: isSubmitting,
                    onStarTap: onStarTap,
                    onSubmit: onSubmit,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Already-rated display
// ---------------------------------------------------------------------------

class _RatedDisplay extends StatelessWidget {
  final int rating;
  final String comment;
  final VoidCallback onEdit;

  const _RatedDisplay(
      {required this.rating,
      required this.comment,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 15, color: AppColors.success),
            const SizedBox(width: 6),
            const Text('Your Rating',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: i < rating ? Colors.amber : AppColors.textHint,
                );
              }),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onEdit,
              child: const Text('Edit',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"$comment"',
              style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rating input
// ---------------------------------------------------------------------------

class _RatingInput extends StatelessWidget {
  final String entryId;
  final String entryType;
  final String businessId;
  final String businessName;
  final int stars;
  final TextEditingController controller;
  final bool isSubmitting;
  final void Function(String, int) onStarTap;
  final Future<void> Function(String, String, String, String) onSubmit;

  const _RatingInput({
    required this.entryId,
    required this.entryType,
    required this.businessId,
    required this.businessName,
    required this.stars,
    required this.controller,
    required this.isSubmitting,
    required this.onStarTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rate this experience',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            return GestureDetector(
              onTap: () => onStarTap(entryId, i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  i < stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 30,
                  color: i < stars ? Colors.amber : AppColors.textHint,
                ),
              ),
            );
          }),
        ),
        if (stars > 0) ...[
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Add a comment (optional)',
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: 13),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () => onSubmit(entryId, entryType, businessId, businessName),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Rating',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: AppColors.glassBorder, width: 0.5),
              ),
              child: Icon(icon, size: 32, color: AppColors.textHint),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
