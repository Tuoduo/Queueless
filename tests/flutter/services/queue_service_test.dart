// tests/flutter/services/queue_service_test.dart
//
// QueueLess — QueueService unit tests

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/queue_model.dart';
import 'package:queueless/services/queue_service.dart';

void main() {
  group('QueueService', () {
    // ── 34. getQueue creates queue on first call ───────────────────────────
    test('getQueue returns a new QueueModel for an unknown businessId', () async {
      final queue = await QueueService().getQueue('fresh-biz');
      expect(queue.businessId, equals('fresh-biz'));
      expect(queue.entries, isEmpty);
    });

    // ── 35. joinQueue adds a waiting entry ─────────────────────────────────
    test('joinQueue adds a waiting entry with the correct customer name', () async {
      final entry = await QueueService().joinQueue(
        businessId: 'biz-test-1',
        customerId: 'cust-001',
        customerName: 'Alice',
      );
      expect(entry.customerName, equals('Alice'));
      expect(entry.status, equals(QueueEntryStatus.waiting));
      expect(entry.position, equals(1));
    });

    // ── 36. joinQueue throws on duplicate ─────────────────────────────────
    test('joinQueue throws if customer is already in the queue', () async {
      const bizId  = 'biz-duplicate-check';
      const custId = 'cust-002';
      await QueueService().joinQueue(
        businessId: bizId, customerId: custId, customerName: 'Bob',
      );
      expect(
        () => QueueService().joinQueue(
          businessId: bizId, customerId: custId, customerName: 'Bob',
        ),
        throwsException,
      );
    });

    // ── 37. leaveQueue cancels the entry ──────────────────────────────────
    test('leaveQueue sets the entry status to cancelled', () async {
      const bizId = 'biz-leave-test';
      final entry = await QueueService().joinQueue(
        businessId: bizId, customerId: 'cust-003', customerName: 'Carol',
      );
      await QueueService().leaveQueue(bizId, entry.id);
      final queue = await QueueService().getQueue(bizId);
      final found = queue.entries.firstWhere((e) => e.id == entry.id);
      expect(found.status, equals(QueueEntryStatus.cancelled));
    });

    // ── 38. callNextCustomer moves first waiting to serving ────────────────
    test('callNextCustomer moves first waiting entry to serving', () async {
      const bizId = 'biz-call-next';
      await QueueService().joinQueue(
        businessId: bizId, customerId: 'cust-004a', customerName: 'Dave',
      );
      await QueueService().joinQueue(
        businessId: bizId, customerId: 'cust-004b', customerName: 'Eve',
      );
      await QueueService().callNextCustomer(bizId);
      final queue   = await QueueService().getQueue(bizId);
      final serving = queue.entries
          .where((e) => e.status == QueueEntryStatus.serving)
          .toList();
      expect(serving.length, equals(1));
      expect(serving.first.customerName, equals('Dave'));
    });

    // ── 39. getUserActiveQueues returns only active entries ────────────────
    test('getUserActiveQueues returns waiting and serving entries for a customer', () async {
      const custId = 'cust-active-check';
      await QueueService().joinQueue(
        businessId: 'biz-a', customerId: custId, customerName: 'Frank',
      );
      final active = await QueueService().getUserActiveQueues(custId);
      expect(active, isNotEmpty);
      expect(
        active.every(
          (e) =>
            e.status == QueueEntryStatus.waiting ||
            e.status == QueueEntryStatus.serving,
        ),
        isTrue,
      );
    });
  });
}
