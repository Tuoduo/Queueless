import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/business_model.dart';
import '../../../providers/business_provider.dart';
import '../../../widgets/business_card.dart';
import '../../../widgets/business_map_panel.dart';
import '../../../widgets/loading_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/page_transitions.dart';
import 'business_detail_screen.dart';

enum _DiscoverView { list, map }

class BusinessListScreen extends StatefulWidget {
  const BusinessListScreen({super.key});

  @override
  State<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends State<BusinessListScreen> {
  final _searchController = TextEditingController();
  BusinessCategory? _selectedCategory;
  bool _searchFocused = false;
  _DiscoverView _discoverView = _DiscoverView.list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusinessProvider>(context, listen: false).loadBusinesses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        _buildCategoryFilter(context),
        _buildViewToggle(),
        const SizedBox(height: 4),
        Expanded(
          child: Consumer<BusinessProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading && provider.businesses.isEmpty) {
                return const LoadingWidget(message: 'Loading businesses...');
              }

              if (provider.error != null) {
                return Center(child: Text('Error: ${provider.error}'));
              }

              if (provider.businesses.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () => provider.loadBusinesses(),
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _discoverView == _DiscoverView.list
                      ? ListView.builder(
                          key: const ValueKey('discover_list'),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.businesses.length,
                          itemBuilder: (context, index) {
                            final business = provider.businesses[index];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 450 + (index * 60)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: BusinessCard(
                                business: business,
                                onTap: () => _openBusiness(context, business),
                              ),
                            );
                          },
                        )
                      : ListView(
                          key: const ValueKey('discover_map'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            SizedBox(
                              height: 560,
                              child: BusinessMapPanel(
                                businesses: provider.businesses,
                                onOpenBusiness: (business) => _openBusiness(context, business),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openBusiness(BuildContext context, BusinessModel business) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surfaceLight, AppColors.surface],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            const Text('No businesses found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Try a different search or category', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Focus(
        onFocusChange: (focused) => setState(() => _searchFocused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _searchFocused ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocused ? AppColors.primary.withValues(alpha: 0.4) : AppColors.glassBorder,
              width: _searchFocused ? 1.5 : 0.5,
            ),
            boxShadow: _searchFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search businesses...',
              hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.7), fontSize: 14),
              prefixIcon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _searchFocused ? Icons.search : Icons.search,
                  key: ValueKey(_searchFocused),
                  color: _searchFocused ? AppColors.primary : AppColors.textHint,
                  size: 20,
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        Provider.of<BusinessProvider>(context, listen: false).searchBusinesses('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (value) {
              setState(() {});
              Provider.of<BusinessProvider>(context, listen: false).searchBusinesses(value);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(context, null, '✨ All'),
          ...BusinessCategory.values.map(
            (cat) => _buildFilterChip(
              context,
              cat,
              '${_getCategoryEmoji(cat)} ${cat.name[0].toUpperCase()}${cat.name.substring(1)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildViewChip(
              label: 'List',
              icon: Icons.view_agenda_rounded,
              selected: _discoverView == _DiscoverView.list,
              onTap: () => setState(() => _discoverView = _DiscoverView.list),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildViewChip(
              label: 'Map',
              icon: Icons.map_outlined,
              selected: _discoverView == _DiscoverView.map,
              onTap: () => setState(() => _discoverView = _DiscoverView.map),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewChip({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textHint),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(BusinessCategory cat) {
    switch (cat) {
      case BusinessCategory.bakery: return '🍰';
      case BusinessCategory.barber: return '💈';
      case BusinessCategory.restaurant: return '🍽️';
      case BusinessCategory.clinic: return '🏥';
      case BusinessCategory.bank: return '🏦';
      case BusinessCategory.repair: return '🛠️';
      case BusinessCategory.beauty: return '💅';
      case BusinessCategory.dentist: return '🦷';
      case BusinessCategory.gym: return '🏋️';
      case BusinessCategory.pharmacy: return '💊';
      case BusinessCategory.grocery: return '🛒';
      case BusinessCategory.government: return '🏛️';
      case BusinessCategory.cafe: return '☕';
      case BusinessCategory.vet: return '🐾';
      case BusinessCategory.other: return '🏪';
    }
  }

  Widget _buildFilterChip(BuildContext context, BusinessCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = isSelected ? null : category;
          });
          Provider.of<BusinessProvider>(context, listen: false).filterByCategory(_selectedCategory);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.glassBorder,
              width: 0.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
