import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/eta_utils.dart';
import '../models/business_model.dart';

class BusinessMapPanel extends StatelessWidget {
  final List<BusinessModel> businesses;
  final ValueChanged<BusinessModel> onOpenBusiness;

  const BusinessMapPanel({
    super.key,
    required this.businesses,
    required this.onOpenBusiness,
  });

  @override
  Widget build(BuildContext context) {
    final mappedBusinesses = businesses.where((business) => business.hasCoordinates).toList();
    if (mappedBusinesses.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 52, color: AppColors.textHint),
            SizedBox(height: 18),
            Text('No mapped businesses yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'Business owners can add latitude and longitude in Settings to appear on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    final center = _resolveCenter(mappedBusinesses);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: mappedBusinesses.length == 1 ? 14.5 : 6.2,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.queueless.app',
            ),
            MarkerLayer(
              markers: mappedBusinesses.map((business) {
                return Marker(
                  point: LatLng(business.latitude!, business.longitude!),
                  width: 110,
                  height: 110,
                  child: GestureDetector(
                    onTap: () => _showBusinessSheet(context, business),
                    child: _MapMarker(business: business),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  LatLng _resolveCenter(List<BusinessModel> mappedBusinesses) {
    if (mappedBusinesses.isEmpty) {
      return const LatLng(39.0, 35.0);
    }

    final latTotal = mappedBusinesses.fold<double>(0, (sum, business) => sum + (business.latitude ?? 0));
    final lngTotal = mappedBusinesses.fold<double>(0, (sum, business) => sum + (business.longitude ?? 0));
    return LatLng(latTotal / mappedBusinesses.length, lngTotal / mappedBusinesses.length);
  }

  void _showBusinessSheet(BuildContext context, BusinessModel business) {
    final eta = estimateNonlinearEtaRange(
      unitCount: business.waitingCount,
      avgServiceSeconds: business.avgServiceSeconds,
    ).label;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(child: Text(business.categoryIcon, style: const TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(business.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(business.address, style: const TextStyle(color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatChip(icon: Icons.star_rounded, label: 'Rating', value: business.rating.toStringAsFixed(1), color: AppColors.vip),
                  _StatChip(icon: Icons.people_rounded, label: 'Waiting', value: '${business.waitingCount}', color: AppColors.primary),
                  _StatChip(icon: Icons.schedule_rounded, label: 'ETA', value: eta, color: AppColors.secondary),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenBusiness(business);
                  },
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Open Business'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapMarker extends StatelessWidget {
  final BusinessModel business;

  const _MapMarker({required this.business});

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(business.categoryIcon, style: const TextStyle(fontSize: 28)),
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: business.waitingCount > 0 ? AppColors.error : AppColors.success,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                '${business.waitingCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}