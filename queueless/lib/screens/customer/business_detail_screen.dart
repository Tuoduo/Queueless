import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../models/business_model.dart';
import '../../../models/queue_model.dart';
import '../../../providers/queue_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../models/product_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/eta_utils.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/category_background.dart';
import '../../../core/constants/category_themes.dart';
import 'cart_screen.dart';
import '../../models/time_slot_model.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../shared/live_business_chat_screen.dart';

class BusinessDetailScreen extends StatefulWidget {
  final BusinessModel business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> with TickerProviderStateMixin {
  String? _selectedProductId;
  String? _selectedProductName;
  double? _selectedProductPrice;
  int _userRating = 0;
  String _reviewComment = '';
  QueueProvider? _queueProvider;
  bool _hasBeenServed = false;

  // Reviews state
  List<Map<String, dynamic>> _reviews = [];
  int _reviewPage = 1;
  int _totalReviews = 0;
  int _totalPages = 1;
  bool _loadingReviews = false;

  late AnimationController _pulseController;
  late AnimationController _headerController;

  String _cleanError(String msg) {
    return msg.replaceAll(RegExp(r'^Exception:\s*'), '').replaceAll(RegExp(r'^Error:\s*'), '');
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queueProvider = Provider.of<QueueProvider>(context, listen: false);
      _queueProvider!.loadQueue(widget.business.id);
      _queueProvider!.subscribeToQueue(widget.business.id);
      Provider.of<ProductProvider>(context, listen: false).loadBusinessProducts(widget.business.id);
      _loadReviews();
      _checkHasPurchased();
    });
  }

  @override
  void dispose() {
    _queueProvider?.unsubscribeFromQueue();
    _pulseController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews([int page = 1]) async {
    if (_loadingReviews) return;
    setState(() => _loadingReviews = true);
    try {
      final result = await ApiService.get('/businesses/${widget.business.id}/reviews?page=$page&limit=5');
      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(result['reviews'] ?? []);
          _totalReviews = (result['total'] as num?)?.toInt() ?? 0;
          _totalPages = (result['totalPages'] as num?)?.toInt() ?? 1;
          _reviewPage = page;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _checkHasPurchased() async {
    try {
      final result = await ApiService.get('/businesses/${widget.business.id}/has-purchased');
      if (mounted) {
        setState(() => _hasBeenServed = result['hasPurchased'] == true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBusinessInfo(),
                  if (widget.business.hasCoordinates) ...[
                    const SizedBox(height: 16),
                    _buildLocationCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildContactCard(),
                  const SizedBox(height: 20),
                  _buildQueueStatusSection(),
                  const SizedBox(height: 20),
                  if (widget.business.serviceType != ServiceType.queue)
                    _buildActionsRow(),
                  const SizedBox(height: 28),
                  Text(
                    widget.business.serviceType == ServiceType.appointment ? 'Services' : 'Products & Services',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildProductsList(),
          // Reviews section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildReviewsSection(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: _buildCartFAB(),
    );
  }

  Widget? _buildCartFAB() {
    if (widget.business.serviceType != ServiceType.queue) return null;

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, val, child) {
            return Transform.scale(scale: val, child: child);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, SlideUpPageRoute(page: const CartScreen())),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: Badge(
                label: Text(cart.itemCount.toString()),
                child: const Icon(Icons.shopping_basket_rounded),
              ),
              label: const Text('View Basket', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        title: Text(
          widget.business.name,
          style: const TextStyle(
            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or gradient
            if (widget.business.imageUrl != null && widget.business.imageUrl!.isNotEmpty)
              Image.network(
                widget.business.imageUrl!,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return CategoryBackground(
                    theme: CategoryThemes.getTheme(widget.business.category),
                    width: double.maxFinite,
                    height: double.maxFinite,
                    child: const Center(
                      child: SizedBox(
                        width: 40, height: 40,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => CategoryBackground(
                  theme: CategoryThemes.getTheme(widget.business.category),
                  width: double.maxFinite,
                  height: double.maxFinite,
                  child: Center(
                     child: Text(
                      widget.business.categoryIcon,
                      style: const TextStyle(fontSize: 85),
                     ),
                  ),
                ),
              )
            else
              CategoryBackground(
                theme: CategoryThemes.getTheme(widget.business.category),
                width: double.maxFinite,
                height: double.maxFinite,
                child: Container(),
              ),
            
            // Category icon as fallback or overlay
            if (widget.business.imageUrl == null || widget.business.imageUrl!.isEmpty)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(scale: val, child: Opacity(opacity: val.clamp(0.0, 1.0), child: child));
                  },
                  child: Text(
                    widget.business.categoryIcon,
                    style: const TextStyle(fontSize: 85),
                  ),
                ),
              ),
              
            // Bottom gradient fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, AppColors.background],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfo() {
    return Consumer<BusinessProvider>(
      builder: (context, bProvider, _) {
        final biz = bProvider.getBusinessById(widget.business.id) ?? widget.business;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Opacity(opacity: val, child: Transform.translate(
              offset: Offset(0, 12 * (1 - val)), child: child,
            ));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      biz.categoryDisplayName,
                      style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  // Star rating display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.vip.withOpacity(0.12), AppColors.vip.withOpacity(0.04)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ...List.generate(5, (i) {
                          final starValue = i + 1;
                          if (biz.rating >= starValue) {
                            return const Icon(Icons.star_rounded, color: AppColors.vip, size: 16);
                          } else if (biz.rating >= starValue - 0.5) {
                            return const Icon(Icons.star_half_rounded, color: AppColors.vip, size: 16);
                          } else {
                            return Icon(Icons.star_outline_rounded, color: AppColors.vip.withOpacity(0.3), size: 16);
                          }
                        }),
                        const SizedBox(width: 6),
                        Text(
                          '${biz.rating.toStringAsFixed(1)}',
                          style: const TextStyle(color: AppColors.vip, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(biz.description, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.location_on_outlined, biz.address),
              if (biz.phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoRow(Icons.phone_outlined, biz.phone),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.textHint, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }

  Widget _buildContactCard() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null || !auth.isCustomer) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0x2218FFFF), Color(0x1A7B6FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.chat_bubble_rounded, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need to ask the store something?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  'Open a live chat with the business owner and get instant updates here.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveBusinessChatScreen(
                    businessId: widget.business.id,
                    title: widget.business.name,
                    subtitle: 'Live store chat',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Chat Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    if (!widget.business.hasCoordinates) {
      return const SizedBox.shrink();
    }

    final location = LatLng(widget.business.latitude!, widget.business.longitude!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0x2218FFFF), Color(0x164774FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.primaryLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      widget.business.address,
                      style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: location,
                  initialZoom: 15.6,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.queueless.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        width: 94,
                        height: 94,
                        child: Align(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.26),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(widget.business.categoryIcon, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStatusSection() {
    final showQueue = widget.business.serviceType == ServiceType.queue ||
        widget.business.serviceType == ServiceType.both;
    if (!showQueue) return const SizedBox.shrink();

    return Consumer<QueueProvider>(
      builder: (context, queueProvider, _) {
        final queue = queueProvider.currentQueue;
        final waitingCount = queue?.waitingCount ?? 0;
        final avgSec = queue?.avgServiceSeconds ?? queueProvider.avgServiceSeconds;
        final etaConfig = NonLinearEtaConfig.fromAvgServiceSeconds(avgSec);
        final waitingEntries = queueProvider.businessQueue
            .where((entry) => entry.status == QueueEntryStatus.waiting)
            .map(
              (entry) => NonLinearEtaCalculator.equivalentUnits(
                itemCount: entry.itemCount,
                durationMinutes: entry.productDurationMinutes,
                config: etaConfig,
              ),
            )
            .toList();
        final waitRange = NonLinearEtaCalculator.estimateAggregateRange(
          unitCounts: waitingEntries,
          config: etaConfig,
        );
        final waitLabel = waitingCount == 0 ? '<1 min' : waitRange.label;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.surfaceLight, AppColors.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('In Queue', waitingCount.toString(), Icons.people_outline),
              Container(width: 1, height: 50, color: AppColors.divider),
              _buildStatColumn('Wait Time', queue != null ? waitLabel : '-', Icons.schedule_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.secondary.withOpacity(0.12), AppColors.secondary.withOpacity(0.04)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.secondary, size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildActionsRow() {
    final showQueue = widget.business.serviceType == ServiceType.queue || widget.business.serviceType == ServiceType.both;

    return Column(
      children: [
        if (_selectedProductId == null && showQueue)
        Row(
          children: [
            if (showQueue)
              Expanded(
                child: Consumer2<QueueProvider, AuthProvider>(
                  builder: (context, qProvider, auth, _) {
                    final isPaused = qProvider.currentQueue?.isPaused ?? false;
                    final entry = qProvider.currentQueue?.entries.firstWhere(
                      (e) => e.customerId == auth.currentUser?.id &&
                          (e.status == QueueEntryStatus.waiting || e.status == QueueEntryStatus.serving),
                      orElse: () => QueueEntryModel(id: '', customerId: '', customerName: '', businessId: '', position: 0),
                    );

                    final bool alreadyIn = entry?.id != '';

                    if (alreadyIn) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await qProvider.leaveQueue(entry!.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('You have left the queue.')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Leave Queue'),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        gradient: _selectedProductId != null ? AppColors.accentGradient : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedProductId != null ? [
                          BoxShadow(color: AppColors.secondary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                        ] : [],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _selectedProductId == null || isPaused
                            ? null
                            : () async {
                                if (auth.currentUser != null) {
                                  await qProvider.joinQueue(
                                    widget.business.id,
                                  ).then((_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Joined queue for $_selectedProductName!')),
                                    );
                                  }).catchError((error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_cleanError(error.toString())), backgroundColor: AppColors.error),
                                    );
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedProductId != null ? Colors.transparent : null,
                          shadowColor: Colors.transparent,
                        ),
                        icon: Icon(isPaused ? Icons.pause_circle_filled_rounded : Icons.queue_rounded, size: 18),
                        label: Text(isPaused ? 'Queue Paused' : 'Join Queue'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser == null) return const SizedBox.shrink();

    return Consumer<BusinessProvider>(
      builder: (context, bProvider, _) {
        final biz = bProvider.getBusinessById(widget.business.id) ?? widget.business;

        if (!_hasBeenServed) return const SizedBox.shrink();

        if (_userRating > 0) {
          return _buildRatedState(biz);
        }

        return _buildRateState(biz, bProvider);
      },
    );
  }

  Widget _buildRatedState(BusinessModel biz) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.vip.withValues(alpha: 0.05), AppColors.surfaceLight.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.vip.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, val, child) => Transform.scale(scale: val, child: child),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 28),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Thanks for your review!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + i * 80),
                curve: Curves.easeOutBack,
                builder: (context, val, child) => Transform.scale(scale: val, child: child),
                child: Icon(
                  i < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < _userRating ? AppColors.vip : AppColors.textHint,
                  size: 28,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRateState(BusinessModel biz, BusinessProvider bProvider) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.vip.withValues(alpha: 0.04), AppColors.surfaceLight.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.vip.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.vip),
              const SizedBox(width: 8),
              const Text('Rate this Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${biz.ratingCount} reviews', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() => _userRating = starIndex);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _userRating >= starIndex ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _userRating >= starIndex ? AppColors.vip : AppColors.vip.withValues(alpha: 0.5),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (v) => _reviewComment = v,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _userRating > 0
                  ? () async {
                      await bProvider.addRating(
                        widget.business.id,
                        _userRating.toDouble(),
                        comment: _reviewComment,
                      );
                      _loadReviews();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Thanks for rating $_userRating stars!')),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.vip,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Consumer<ProductProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          );
        }

        if (provider.products.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.inventory_2_outlined, size: 42, color: AppColors.textHint.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 14),
                    const Text('No products available right now.', style: TextStyle(color: AppColors.textHint)),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = provider.products[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 60)),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Opacity(opacity: val, child: Transform.translate(
                      offset: Offset(0, 16 * (1 - val)), child: child,
                    ));
                  },
                  child: Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      final isQueue = widget.business.serviceType == ServiceType.queue;
                      final isService = widget.business.serviceType == ServiceType.appointment || widget.business.serviceType == ServiceType.both;
                      final cartItem = cart.items[product.id];
                      final qty = cartItem?.quantity ?? 0;

                      return ProductCard(
                        product: product,
                        isSelected: qty > 0,
                        isService: isService,
                        quantity: isQueue ? qty : 0,
                        onAdd: isQueue ? () {
                          _handleQueueProductAdd(cart, product);
                        } : null,
                        onRemove: isQueue ? () {
                          cart.removeSingleItem(product.id);
                        } : null,
                        onOrder: isService ? () {
                          _showServiceConfirmationSheet(context, product);
                        } : null,
                      );
                    },
                  ),
                );
              },
              childCount: provider.products.length,
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleQueueProductAdd(CartProvider cart, ProductModel product) async {
    if (!cart.requiresBusinessSwitch(product)) {
      cart.addItem(product);
      return;
    }

    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Replace Cart Items?'),
        content: const Text(
          'Your cart already contains items from another business. Those items will be removed if you continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );

    if (shouldReplace == true) {
      cart.addItem(product, replaceExisting: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Previous cart items were removed.')),
      );
    }
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.reviews_outlined, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Reviews ($_totalReviews)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingReviews && _reviews.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('No reviews yet', style: TextStyle(color: AppColors.textHint))),
          )
        else ...[
          ..._reviews.map((review) {
            final stars = (review['rating'] as num?)?.toInt() ?? 0;
            final name = review['customer_name']?.toString() ?? 'Customer';
            final comment = review['comment']?.toString() ?? '';
            final products = review['products_purchased']?.toString() ?? '';
            final replyText = review['reply_text']?.toString().trim() ?? '';
            final replyDate = review['reply_date'] != null
                ? DateTime.tryParse(review['reply_date'].toString())
                : null;
            final date = review['created_at'] != null
                ? DateTime.tryParse(review['created_at'].toString())
                : null;

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
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            if (date != null)
                              Text(DateFormat('MMM dd, yyyy').format(date),
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => Icon(
                          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: i < stars ? AppColors.vip : AppColors.textHint,
                          size: 16,
                        )),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(comment, style: const TextStyle(fontSize: 13)),
                  ],
                  if (products.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 12, color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(products, style: const TextStyle(color: AppColors.primaryLight, fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (replyText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.reply_rounded, size: 14, color: AppColors.success),
                              const SizedBox(width: 6),
                              const Text(
                                'Business Reply',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                              const Spacer(),
                              if (replyDate != null)
                                Text(
                                  DateFormat('MMM dd, yyyy').format(replyDate),
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(replyText, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          // Pagination
          if (_totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final page = i + 1;
                final isActive = page == _reviewPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: isActive ? null : () => _loadReviews(page),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isActive ? AppColors.primaryGradient : null,
                        color: isActive ? null : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$page',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.textHint,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ],
    );
  }

  void _showServiceConfirmationSheet(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textHint.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Do you want to book this service?', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.design_services_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomSheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.glassBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          setState(() {
                            _selectedProductId = product.id;
                            _selectedProductName = product.name;
                            _selectedProductPrice = product.price;
                          });
                          _showBookingSheet(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Yes, Select Time', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  void _showBookingSheet(BuildContext outerContext) async {
    DateTime selectedDate = DateTime.now();
    TimeSlotModel? selectedSlot;
    final couponController = TextEditingController();
    String discountCode = '';
    bool isValidatingCoupon = false;
    String? couponError;
    Map<String, dynamic>? appliedDiscount;

    final apptProvider = Provider.of<AppointmentProvider>(outerContext, listen: false);
    await apptProvider.loadAvailableSlots(widget.business.id, selectedDate);

    if (!mounted) return;


    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Consumer<AppointmentProvider>(
          builder: (context, apptProvider, _) => Container(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
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
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Book Appointment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (_selectedProductName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.design_services_outlined, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text('$_selectedProductName', style: const TextStyle(color: AppColors.primaryLight, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateFormat('EEEE, MMM dd, yyyy').format(selectedDate)),
                    style: OutlinedButton.styleFrom(side: BorderSide.none),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          selectedDate = picked;
                          selectedSlot = null;
                        });
                        apptProvider.loadAvailableSlots(widget.business.id, picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Available Slots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (apptProvider.isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (apptProvider.availableSlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 36, color: AppColors.textHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        const Text('No slots for this day', style: TextStyle(color: AppColors.textHint)),
                        const Text('Try another date', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: apptProvider.availableSlots.length,
                      itemBuilder: (context, index) {
                        final slot = apptProvider.availableSlots[index];
                        final isSelected = selectedSlot?.id == slot.id;
                        final bool isBooked = slot.isBooked;

                        return GestureDetector(
                          onTap: isBooked ? null : () {
                            setSheetState(() {
                              selectedSlot = isSelected ? null : slot;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppColors.primaryGradient : null,
                              color: isSelected ? null : (isBooked ? AppColors.surface : AppColors.surfaceLight),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isBooked ? AppColors.divider : AppColors.glassBorder),
                                width: 0.5,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8),
                              ] : [],
                            ),
                            child: Center(
                              child: Text(
                                DateFormat('HH:mm').format(slot.startTime),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isBooked ? AppColors.textHint : AppColors.textPrimary),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  decoration: isBooked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                // Discount coupon field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discount Coupon (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (appliedDiscount == null) ...[  
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: couponController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Enter coupon code',
                                prefixIcon: const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.textHint),
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                                ),
                                errorText: couponError,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              onChanged: (v) => setSheetState(() {
                                discountCode = v.trim();
                                couponError = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          isValidatingCoupon
                            ? const SizedBox(
                                width: 44, height: 44,
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            : ElevatedButton(
                                onPressed: discountCode.isEmpty ? null : () async {
                                  setSheetState(() { isValidatingCoupon = true; couponError = null; });
                                  try {
                                    final result = await ApiService.post('/discounts/validate', {
                                      'businessId': widget.business.id,
                                      'code': discountCode,
                                      'amount': _selectedProductPrice ?? 0,
                                    });
                                    setSheetState(() {
                                      if (result['valid'] == true) {
                                        appliedDiscount = result;
                                      } else {
                                        couponError = 'Invalid or expired coupon';
                                      }
                                      isValidatingCoupon = false;
                                    });
                                  } catch (_) {
                                    setSheetState(() {
                                      couponError = 'Could not validate coupon';
                                      isValidatingCoupon = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                        ],
                      ),
                    ] else ...[  
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Coupon "$discountCode" applied',
                                style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setSheetState(() {
                                appliedDiscount = null;
                                discountCode = '';
                                couponController.clear();
                              }),
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: selectedSlot != null ? AppColors.primaryGradient : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selectedSlot != null ? [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ] : [],
                  ),
                  child: ElevatedButton(
                    onPressed: selectedSlot == null
                        ? null
                        : () async {
                            try {
                              await apptProvider.bookAppointment(
                                businessId: widget.business.id,
                                dateTime: selectedSlot!.startTime,
                                slotId: selectedSlot!.id,
                                serviceName: _selectedProductName,
                                notes: 'Service: $_selectedProductName',
                                discountCode: discountCode.isNotEmpty ? discountCode : null,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Appointment booked for ${DateFormat('MMM dd HH:mm').format(selectedSlot!.startTime)}')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_cleanError(e.toString())), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedSlot != null ? Colors.transparent : null,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (selectedSlot != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded, size: 20),
                        ],
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
}
