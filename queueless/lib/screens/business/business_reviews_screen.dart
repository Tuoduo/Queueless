import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/api_service.dart';

class BusinessReviewsScreen extends StatefulWidget {
  const BusinessReviewsScreen({super.key});

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  String? _loadedBusinessId;
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _replyLoading = {};
  final Map<String, bool> _editingReplies = {};

  int get _totalPages => (_total / 10).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureBusinessAndLoad();
    });
  }

  Future<void> _ensureBusinessAndLoad([int page = 1]) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bProvider = Provider.of<BusinessProvider>(context, listen: false);
    final ownerId = auth.currentUser?.id ?? '';

    if (ownerId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Owner session not found';
      });
      return;
    }

    var business = bProvider.getBusinessByOwnerId(ownerId);
    if (business == null) {
      await bProvider.loadOwnerBusiness(ownerId);
      business = bProvider.getBusinessByOwnerId(ownerId);
    }

    if (business == null) {
      if (!mounted) return;
      setState(() {
        _error = 'No business found';
      });
      return;
    }

    await _loadReviews(business.id, page: page);
  }

  Future<void> _loadReviews(String businessId, {int page = 1}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.get('/businesses/$businessId/reviews?page=$page&limit=10');
      if (!mounted) return;
      setState(() {
        _loadedBusinessId = businessId;
        _page = page;
        _reviews = List<Map<String, dynamic>>.from(result['reviews'] ?? const []);
        _total = (result['total'] as num?)?.toInt() ?? 0;
      });

      for (final review in _reviews) {
        final reviewId = review['id']?.toString() ?? '';
        if (reviewId.isEmpty || _editingReplies[reviewId] == true) continue;
        final replyText = review['reply_text']?.toString() ?? '';
        final controller = _replyControllers.putIfAbsent(
          reviewId,
          () => TextEditingController(text: replyText),
        );
        if (controller.text != replyText) {
          controller.text = replyText;
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  TextEditingController _getReplyController(String reviewId, [String initialText = '']) {
    return _replyControllers.putIfAbsent(
      reviewId,
      () => TextEditingController(text: initialText),
    );
  }

  void _startEditingReply(String reviewId, String replyText) {
    final controller = _getReplyController(reviewId, replyText);
    controller.text = replyText;
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    setState(() => _editingReplies[reviewId] = true);
  }

  void _cancelEditingReply(String reviewId, String replyText) {
    final controller = _getReplyController(reviewId, replyText);
    controller.text = replyText;
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    setState(() => _editingReplies[reviewId] = false);
  }

  Future<void> _submitReply(String reviewId) async {
    final controller = _getReplyController(reviewId);
    if (controller.text.trim().isEmpty) return;
    if (_loadedBusinessId == null) return;

    setState(() => _replyLoading[reviewId] = true);
    try {
      await ApiService.post('/businesses/$_loadedBusinessId/reviews/$reviewId/reply', {
        'reply_text': controller.text.trim(),
      });
      if (mounted) {
        setState(() => _editingReplies[reviewId] = false);
        await _loadReviews(_loadedBusinessId!, page: _page);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reply: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _replyLoading[reviewId] = false);
    }
  }

  @override
  void dispose() {
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final businessProvider = Provider.of<BusinessProvider>(context);
    final business = businessProvider.getBusinessByOwnerId(auth.currentUser?.id ?? '');

    if (_loadedBusinessId != business?.id && business != null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadReviews(business.id);
      });
    }

    return RefreshIndicator(
      onRefresh: () => _ensureBusinessAndLoad(_page),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(business),
          const SizedBox(height: 16),
          if (_isLoading && _reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildErrorCard()
          else if (_reviews.isEmpty)
            _buildEmptyCard()
          else ...[
            ..._reviews.map(_buildReviewCard),
            if (_totalPages > 1) ...[
              const SizedBox(height: 8),
              _buildPagination(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(dynamic business) {
    final rating = (business?.rating as num?)?.toDouble() ?? 0.0;
    final count = (business?.ratingCount as num?)?.toInt() ?? _total;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  count > 0 ? '$count reviews collected from completed orders' : 'No customer reviews yet',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.vip, size: 16),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text('$count total', style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        _error ?? 'Could not load reviews',
        style: const TextStyle(color: AppColors.error),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.reviews_outlined, size: 40, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('No reviews yet', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Customer comments and ratings will appear here.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final stars = (review['rating'] as num?)?.toInt() ?? 0;
    final name = review['customer_name']?.toString() ?? 'Customer';
    final comment = review['comment']?.toString().trim() ?? '';
    final products = review['products_purchased']?.toString().trim() ?? '';
    final createdAt = review['created_at'] != null ? DateTime.tryParse(review['created_at'].toString()) : null;
    final replyText = review['reply_text']?.toString().trim() ?? '';
    final replyDate = review['reply_date'] != null ? DateTime.tryParse(review['reply_date'].toString()) : null;
    final reviewId = review['id']?.toString() ?? '';
    final hasReply = replyText.isNotEmpty;
    final isEditingReply = _editingReplies[reviewId] == true;
    final replyController = _getReplyController(reviewId, replyText);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (createdAt != null)
                      Text(DateFormat('dd MMM yyyy').format(createdAt), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < stars ? AppColors.vip : AppColors.textHint,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(comment, style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
          if (products.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      products,
                      style: const TextStyle(color: AppColors.primaryLight, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Existing reply
          if (hasReply && !isEditingReply) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      const Text('Your Reply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                      const Spacer(),
                      if (replyDate != null)
                        Text(DateFormat('dd MMM yyyy').format(replyDate), style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _startEditingReply(reviewId, replyText),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(replyText, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                ],
              ),
            ),
          ],
          if ((!hasReply || isEditingReply) && reviewId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyController,
                    decoration: InputDecoration(
                      hintText: hasReply ? 'Edit your reply...' : 'Write a reply...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textHint),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                if (hasReply) ...[
                  IconButton(
                    onPressed: () => _cancelEditingReply(reviewId, replyText),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _replyLoading[reviewId] == true
                    ? const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        onPressed: () => _submitReply(reviewId),
                        icon: Icon(hasReply ? Icons.save_rounded : Icons.send_rounded, color: AppColors.primary, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_totalPages, (index) {
        final pageNumber = index + 1;
        final isActive = pageNumber == _page;
        return InkWell(
          onTap: isActive ? null : () => _ensureBusinessAndLoad(pageNumber),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isActive ? AppColors.primaryGradient : null,
              color: isActive ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pageNumber',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textHint,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }
}