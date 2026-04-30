import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants/app_colors.dart';

class BusinessLocationPicker extends StatefulWidget {
  final bool isEditing;
  final LatLng? selectedLocation;
  final ValueChanged<LatLng?> onLocationChanged;

  const BusinessLocationPicker({
    super.key,
    required this.isEditing,
    required this.selectedLocation,
    required this.onLocationChanged,
  });

  @override
  State<BusinessLocationPicker> createState() => _BusinessLocationPickerState();
}

class _BusinessLocationPickerState extends State<BusinessLocationPicker> {
  static const LatLng _fallbackCenter = LatLng(39.0, 35.0);

  final MapController _mapController = MapController();
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMapToSelection(forceZoom: true));
  }

  @override
  void didUpdateWidget(covariant BusinessLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final locationChanged = oldWidget.selectedLocation?.latitude != widget.selectedLocation?.latitude
        || oldWidget.selectedLocation?.longitude != widget.selectedLocation?.longitude;
    if (locationChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncMapToSelection());
    }
  }

  double get _targetZoom => widget.selectedLocation != null ? 15.3 : 5.8;

  void _syncMapToSelection({bool forceZoom = false}) {
    final target = widget.selectedLocation ?? _fallbackCenter;
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(target, forceZoom ? _targetZoom : currentZoom.clamp(5.8, 17.5));
    } catch (_) {
      // Ignore early controller access before the map attaches.
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isResolvingLocation = true);

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        throw Exception('Enable location services to use your current shop location.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to place your business with your current position.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final location = LatLng(position.latitude, position.longitude);
      widget.onLocationChanged(location);
      _mapController.move(location, 16);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = widget.selectedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map_rounded, color: AppColors.primaryLight, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Map Placement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    widget.isEditing
                        ? 'Tap the map to place your business pin exactly where customers should find you.'
                        : 'Enable edit mode to move your business pin on the map.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 248,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: selectedLocation ?? _fallbackCenter,
                    initialZoom: _targetZoom,
                    onTap: widget.isEditing
                        ? (_, point) => widget.onLocationChanged(point)
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.queueless.app',
                    ),
                    if (selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation,
                            width: 80,
                            height: 80,
                            child: Align(
                              child: Container(
                                padding: const EdgeInsets.all(12),
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
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: AppColors.secondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedLocation == null
                                ? 'No pin saved yet. Tap on the map to place it.'
                                : 'Pin saved. Tap somewhere else to move it.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: widget.isEditing && !_isResolvingLocation ? _useCurrentLocation : null,
              icon: _isResolvingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.gps_fixed_rounded, size: 18),
              label: Text(_isResolvingLocation ? 'Locating...' : 'Use Current Location'),
            ),
            OutlinedButton.icon(
              onPressed: widget.isEditing && selectedLocation != null ? () => widget.onLocationChanged(null) : null,
              icon: const Icon(Icons.layers_clear_rounded, size: 18),
              label: const Text('Clear Pin'),
            ),
          ],
        ),
      ],
    );
  }
}