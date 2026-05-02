// tests/flutter/models/business_model_test.dart
//
// QueueLess — BusinessModel unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/business_model.dart';

void main() {
  Map<String, dynamic> buildJson({
    String id = 'b-1',
    String name = 'Baklava House',
    String category = 'bakery',
    String serviceType = 'queue',
    bool isActive = true,
    double? latitude,
    double? longitude,
  }) {
    return {
      'id': id, 'owner_id': 'owner-1', 'name': name,
      'description': 'Freshly baked every day.', 'category': category,
      'service_type': serviceType, 'address': '12 Main St', 'phone': '555-9090',
      'is_active': isActive ? 1 : 0, 'approval_status': 'approved',
      'rating': '4.5', 'rating_count': '120', 'total_customers_served': '980',
      'latitude': latitude?.toString(), 'longitude': longitude?.toString(),
      'waiting_count': '5', 'serving_count': '1', 'avg_service_seconds': '300',
    };
  }

  group('BusinessModel', () {
    // ── 16. fromJson parses all basic fields ───────────────────────────────
    test('fromJson creates a valid BusinessModel', () {
      final model = BusinessModel.fromJson(buildJson());
      expect(model.id, equals('b-1'));
      expect(model.category, equals(BusinessCategory.bakery));
      expect(model.serviceType, equals(ServiceType.queue));
      expect(model.isActive, isTrue);
      expect(model.rating, equals(4.5));
    });

    // ── 17. Unknown category falls back to 'other' ─────────────────────────
    test('fromJson maps unknown category to BusinessCategory.other', () {
      final model = BusinessModel.fromJson(buildJson(category: 'spaceship_repair'));
      expect(model.category, equals(BusinessCategory.other));
    });

    // ── 18. hasCoordinates ─────────────────────────────────────────────────
    test('hasCoordinates is true when lat/lng are provided', () {
      final withCoords    = BusinessModel.fromJson(buildJson(latitude: 41.0082, longitude: 28.9784));
      final withoutCoords = BusinessModel.fromJson(buildJson());
      expect(withCoords.hasCoordinates, isTrue);
      expect(withoutCoords.hasCoordinates, isFalse);
    });

    // ── 19. copyWith preserves unchanged fields ───────────────────────────
    test('copyWith only mutates specified fields', () {
      final original = BusinessModel.fromJson(buildJson());
      final updated   = original.copyWith(name: 'New Name', waitingCount: 10);
      expect(updated.name, equals('New Name'));
      expect(updated.waitingCount, equals(10));
      expect(updated.id, equals(original.id));
    });

    // ── 20. categoryDisplayName ───────────────────────────────────────────
    test('categoryDisplayName returns human-readable label', () {
      expect(BusinessModel.fromJson(buildJson(category: 'barber')).categoryDisplayName, equals('Barber'));
      expect(BusinessModel.fromJson(buildJson(category: 'clinic')).categoryDisplayName, equals('Clinic'));
      expect(BusinessModel.fromJson(buildJson(category: 'other')).categoryDisplayName, equals('Other'));
    });

    // ── 21. ServiceType.appointment ───────────────────────────────────────
    test('fromJson parses service_type "appointment" correctly', () {
      final model = BusinessModel.fromJson(buildJson(serviceType: 'appointment'));
      expect(model.serviceType, equals(ServiceType.appointment));
    });

    // ── 22. isActive=0 maps to isActive=false ─────────────────────────────
    test('isActive is false when is_active is 0', () {
      final model = BusinessModel.fromJson(buildJson(isActive: false));
      expect(model.isActive, isFalse);
    });
  });
}
