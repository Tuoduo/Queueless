// tests/flutter/models/user_model_test.dart
//
// QueueLess — UserModel unit tests
// Run: flutter test tests/flutter/models/user_model_test.dart
//      (from inside the queueless/ directory)

import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/user_model.dart';

void main() {
  group('UserModel', () {
    // ── 1. fromMap round-trip ─────────────────────────────────────────────
    test('fromMap creates a valid UserModel with all fields', () {
      final map = {
        'id': 'u-001',
        'name': 'Alice',
        'email': 'alice@example.com',
        'phone': '555-0100',
        'role': 'customer',
        'notificationsEnabled': true,
        'createdAt': '2024-01-15T10:00:00.000',
      };

      final user = UserModel.fromMap(map);

      expect(user.id, equals('u-001'));
      expect(user.name, equals('Alice'));
      expect(user.email, equals('alice@example.com'));
      expect(user.phone, equals('555-0100'));
      expect(user.role, equals(UserRole.customer));
      expect(user.notificationsEnabled, isTrue);
    });

    // ── 2. copyWith preserves unchanged fields ────────────────────────────
    test('copyWith only updates specified fields', () {
      final original = UserModel(
        id: 'u-001',
        name: 'Alice',
        email: 'alice@example.com',
        phone: '555-0100',
        role: UserRole.customer,
      );

      final updated = original.copyWith(name: 'Alicia', phone: '555-9999');

      expect(updated.id, equals(original.id));
      expect(updated.email, equals(original.email));
      expect(updated.role, equals(original.role));
      expect(updated.name, equals('Alicia'));
      expect(updated.phone, equals('555-9999'));
    });

    // ── 3. toMap serialization ────────────────────────────────────────────
    test('toMap produces a map with the correct keys and values', () {
      final user = UserModel(
        id: 'u-002',
        name: 'Bob',
        email: 'bob@example.com',
        phone: '',
        role: UserRole.businessOwner,
        notificationsEnabled: false,
      );

      final map = user.toMap();

      expect(map['id'], equals('u-002'));
      expect(map['role'], equals('businessOwner'));
      expect(map['notificationsEnabled'], isFalse);
    });

    // ── 4. Role parsing — businessOwner and admin ─────────────────────────
    test('fromMap parses businessOwner and admin roles correctly', () {
      final ownerMap = {
        'id': 'o-1', 'name': 'Owner', 'email': 'o@biz.com',
        'phone': '', 'role': 'businessOwner',
        'notificationsEnabled': 1, 'createdAt': null,
      };
      final adminMap = {
        'id': 'a-1', 'name': 'Admin', 'email': 'admin@app.com',
        'phone': '', 'role': 'admin',
        'notificationsEnabled': 1, 'createdAt': null,
      };

      expect(UserModel.fromMap(ownerMap).role, equals(UserRole.businessOwner));
      expect(UserModel.fromMap(adminMap).role, equals(UserRole.admin));
    });

    // ── 5. notificationsEnabled defaults to true ──────────────────────────
    test('notificationsEnabled defaults to true when not provided', () {
      final user = UserModel(
        id: 'u-3',
        name: 'Carol',
        email: 'carol@example.com',
        phone: '',
        role: UserRole.customer,
      );
      expect(user.notificationsEnabled, isTrue);
    });
  });
}
