import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeug/local/discovery_pages.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/app_theme.dart';

void main() {
  test(
    'safety recommendations use activity, location and time without unrelated matches',
    () {
      final tips = <Record>[
        {'id': 'general', 'tags': 'general'},
        {'id': 'forest', 'tags': 'bwindi gorilla forest'},
        {'id': 'night', 'tags': 'night evening'},
        {'id': 'water', 'tags': 'boat rafting jinja'},
      ];
      expect(
        recommendedSafetyTips(
          tips,
          'Bwindi',
          'Gorilla trekking',
          'Night',
        ).map((t) => t['id']),
        ['forest', 'night', 'general'],
      );
      expect(
        recommendedSafetyTips(
          tips,
          'Jinja',
          'Rafting',
          'Day',
        ).map((t) => t['id']),
        ['water', 'general'],
      );
    },
  );
  testWidgets(
    'guide signup is reachable on a narrow screen without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = LocalStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSafeUgTheme(brightness: Brightness.light),
          home: Scaffold(body: GuideDirectory(store: store)),
        ),
      );
      await tester.tap(find.text('Sign up as a guide'));
      await tester.pumpAndSettle();
      expect(find.text('Guide signup'), findsOneWidget);
      expect(find.text('Guide or business name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'protected areas retain unknown area and qualified source in dark mode',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = LocalStore();
      store.data['parks'] = [
        {
          'id': 'test',
          'name': 'Test sanctuary',
          'categoryGroup': 'Sanctuaries',
          'areaKm2': null,
          'sourceWorkbook': 'Factbook.xlsx',
          'sourceSheet': 'Sanctuaries',
          'sourceRow': 4,
          'notes': 'Historic and overlapping',
          'referenceOnly': false,
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSafeUgTheme(brightness: Brightness.dark),
          home: Scaffold(body: ProtectedAreaExplorer(store: store)),
        ),
      );
      expect(find.text('1 named listings'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Test sanctuary'), 300);
      await tester.ensureVisible(find.text('Test sanctuary'));
      await tester.pumpAndSettle();
      expect(find.text('Area not supplied'), findsOneWidget);
      await tester.tap(find.text('Test sanctuary'));
      await tester.pumpAndSettle();
      expect(find.text('Explore a protected area'), findsOneWidget);
      expect(find.text('Test sanctuary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
