// tests/flutter/models/appointment_model_test.dart
//
// QueueLess — AppointmentModel unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/appointment_model.dart';

void main() {
  Map<String, dynamic> buildJson({
    String status = 'pending',
    dynamic finalPrice,
    dynamic originalPrice,
    int durationMinutes = 30,
  }) {
    return {
      'id': 'appt-1', 'business_id': 'b-1',
      'customer_id': 'c-1', 'customer_name': 'Alice',
      'date_time': '2024-07-15T14:00:00.000Z', 'status': status,
      'notes': 'Window seat please', 'service_name': 'Haircut',
      'final_price': finalPrice, 'original_price': originalPrice,
      'discount_amount': '5.00', 'discount_code': null,
      'service_duration_minutes': durationMinutes.toString(),
    };
  }

  group('AppointmentModel', () {
    // ── 23. All statuses parse correctly ──────────────────────────────────
    test('fromJson parses all AppointmentStatus values', () {
      for (final status in AppointmentStatus.values) {
        final model = AppointmentModel.fromJson(buildJson(status: status.name));
        expect(model.status, equals(status));
      }
    });

    // ── 24. durationLabel formatting ──────────────────────────────────────
    test('durationLabel formats durations correctly', () {
      expect(AppointmentModel.fromJson(buildJson(durationMinutes: 45)).durationLabel, equals('45 min'));
      expect(AppointmentModel.fromJson(buildJson(durationMinutes: 75)).durationLabel, equals('1h 15m'));
      expect(AppointmentModel.fromJson(buildJson(durationMinutes: 60)).durationLabel, equals('1h'));
    });

    // ── 25. displayPrice prefers finalPrice ───────────────────────────────
    test('displayPrice returns finalPrice when both are set', () {
      final model = AppointmentModel.fromJson(
        buildJson(finalPrice: '18.50', originalPrice: '25.00'),
      );
      expect(model.displayPrice, closeTo(18.50, 0.001));
    });

    // ── 26. displayPrice falls back to originalPrice ──────────────────────
    test('displayPrice falls back to originalPrice when finalPrice is null', () {
      final model = AppointmentModel.fromJson(
        buildJson(finalPrice: null, originalPrice: '25.00'),
      );
      expect(model.displayPrice, closeTo(25.0, 0.001));
    });

    // ── 27. copyWith preserves other fields ───────────────────────────────
    test('copyWith changes status but preserves other fields', () {
      final original = AppointmentModel.fromJson(buildJson());
      final updated  = original.copyWith(status: AppointmentStatus.confirmed);
      expect(updated.status, equals(AppointmentStatus.confirmed));
      expect(updated.id, equals(original.id));
      expect(updated.customerName, equals(original.customerName));
    });

    // ── 28. discountAmount parses correctly ───────────────────────────────
    test('fromJson parses discountAmount as a double', () {
      final model = AppointmentModel.fromJson(buildJson());
      expect(model.discountAmount, closeTo(5.0, 0.001));
    });
  });
}
