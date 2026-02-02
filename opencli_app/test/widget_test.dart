// OpenCLI widget test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencli_app/main.dart';

void main() {
  testWidgets('OpenCLI app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OpenCLIApp());

    // Verify that app loads with bottom navigation
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
