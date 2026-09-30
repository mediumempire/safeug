import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safeug/screens/landing_screen.dart';

void main() {
  testWidgets('renders the SafeUG landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    expect(find.text('SafeUG'), findsOneWidget);
    expect(find.textContaining('The Pearl of Africa'), findsOneWidget);
  });
}
