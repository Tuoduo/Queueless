// tests/flutter/models/queue_model_test.dart
//
// QueueLess — QueueModel & QueueEntryModel unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/queue_model.dart';

void main() {
  QueueEntryModel buildEntry({
    String id = 'e-1',
    int position = 1,
    QueueEntryStatus status = QueueEntryStatus.waiting,
    bool isVIP = false,
  }) {
    return QueueEntryModel(
      id: id,
      customerId: 'c-1',
      customerName: 'Alice',
      businessId: 'b-1',
      position: position,
      isVIP: isVIP,
      status: status,
    );
  }

  group('QueueEntryModel', () {
    // ── 6. fromJson round-trip ──────────────────────────────────────────────
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'entry-123', 'customer_id': 'cust-456', 'customer_name': 'Bob',
        'business_id': 'biz-789', 'position': '2', 'is_vip': 0,
        'joined_at': '2024-05-01T09:00:00.000Z', 'status': 'waiting',
        'product_name': '2x Baklava', 'people_ahead': '1',
        'avg_service_seconds': '300', 'product_duration_minutes': '15',
        'item_count': '2', 'total_price': '25.00',
        'payment_method': 'later', 'discount_amount': '0',
      };

      final entry = QueueEntryModel.fromJson(json);

      expect(entry.id, equals('entry-123'));
      expect(entry.position, equals(2));
      expect(entry.status, equals(QueueEntryStatus.waiting));
      expect(entry.totalPrice, equals(25.0));
      expect(entry.isVIP, isFalse);
    });

    // ── 7. 'done' status maps to completed ─────────────────────────────────
    test('fromJson maps "done" status to QueueEntryStatus.completed', () {
      final json = {
        'id': 'e-2', 'customer_id': 'c-2', 'customer_name': 'Carol',
        'business_id': 'b-1', 'position': '0', 'is_vip': 0,
        'status': 'done', 'total_price': '0',
        'payment_method': 'later', 'discount_amount': '0',
      };
      expect(QueueEntryModel.fromJson(json).status, equals(QueueEntryStatus.completed));
    });

    // ── 8. isArrivalConfirmed ───────────────────────────────────────────────
    test('isArrivalConfirmed is false when arrivalConfirmedAt is null', () {
      expect(buildEntry().isArrivalConfirmed, isFalse);
    });

    // ── 9. durationLabel formats 90 min correctly ───────────────────────────
    test('durationLabel returns "1h 30m" for 90 minutes', () {
      final entry = QueueEntryModel(
        id: 'e-3', customerId: 'c-3', customerName: 'Dave',
        businessId: 'b-1', position: 1, productDurationMinutes: 90,
      );
      expect(entry.durationLabel, equals('1h 30m'));
    });

    // ── 10. paymentMethodLabel ──────────────────────────────────────────────
    test('paymentMethodLabel returns "Paid with card" for method "now"', () {
      final entry = QueueEntryModel(
        id: 'e-4', customerId: 'c-4', customerName: 'Eve',
        businessId: 'b-1', position: 1, paymentMethod: 'now',
      );
      expect(entry.paymentMethodLabel, equals('Paid with card'));
    });
  });

  group('QueueModel', () {
    // ── 11. waitingEntries filters correctly ───────────────────────────────
    test('waitingEntries returns only waiting entries', () {
      final queue = QueueModel(
        id: 'q-1', businessId: 'b-1',
        entries: [
          buildEntry(id: 'e-1', status: QueueEntryStatus.waiting),
          buildEntry(id: 'e-2', status: QueueEntryStatus.serving),
          buildEntry(id: 'e-3', status: QueueEntryStatus.completed),
          buildEntry(id: 'e-4', status: QueueEntryStatus.waiting),
        ],
      );
      expect(queue.waitingEntries.length, equals(2));
    });

    // ── 12. currentEntry returns serving entry ─────────────────────────────
    test('currentEntry returns the entry with serving status', () {
      final serving = buildEntry(id: 'e-serving', status: QueueEntryStatus.serving);
      final queue = QueueModel(
        id: 'q-2', businessId: 'b-1',
        entries: [buildEntry(id: 'e-1', status: QueueEntryStatus.waiting), serving],
      );
      expect(queue.currentEntry, equals(serving));
    });

    // ── 13. currentEntry is null when nobody is serving ────────────────────
    test('currentEntry is null when no entry is serving', () {
      final queue = QueueModel(
        id: 'q-3', businessId: 'b-1',
        entries: [buildEntry(id: 'e-1', status: QueueEntryStatus.waiting)],
      );
      expect(queue.currentEntry, isNull);
    });

    // ── 14. copyWith toggles isPaused ─────────────────────────────────────
    test('copyWith correctly toggles isPaused', () {
      final queue  = QueueModel(id: 'q-4', businessId: 'b-1', isPaused: false);
      final paused = queue.copyWith(isPaused: true);
      expect(paused.isPaused, isTrue);
      expect(paused.id, equals('q-4'));
    });

    // ── 15. fromJson ───────────────────────────────────────────────────────
    test('fromJson sets isActive from is_open and parses stats', () {
      final json = {
        'id': 'q-5', 'business_id': 'b-1',
        'is_open': 1, 'is_paused': 0,
        'serving_count': '1', 'waiting_count': '3',
        'avg_service_seconds': '240',
      };
      final queue = QueueModel.fromJson(json);
      expect(queue.isActive, isTrue);
      expect(queue.isPaused, isFalse);
      expect(queue.currentServing, equals(1));
      expect(queue.waitingFromServer, equals(3));
      expect(queue.avgServiceSeconds, equals(240));
    });
  });
}
