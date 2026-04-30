import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:queueless/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QueueLessApp());

    // Verify that it runs.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
