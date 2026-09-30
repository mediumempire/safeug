import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safeug/app_theme.dart';
import 'package:safeug/local/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'follows device initially and remembers the mobile theme choice',
    () async {
      final controller = ThemeController();
      await controller.initialize();
      expect(controller.mode, ThemeMode.system);
      await controller.toggle(Brightness.light);
      expect(controller.mode, ThemeMode.dark);
      controller.dispose();

      final restored = ThemeController();
      await restored.initialize();
      expect(restored.mode, ThemeMode.dark);
      await restored.toggle(Brightness.dark);
      expect(restored.mode, ThemeMode.light);
      restored.dispose();
    },
  );

  test('admin and mobile remember independent theme preferences', () async {
    final mobile = ThemeController();
    final admin = ThemeController(adminApp: true);
    await mobile.setMode(ThemeMode.dark);
    await admin.initialize();
    expect(admin.mode, ThemeMode.system);
    await admin.setMode(ThemeMode.light);

    final restoredMobile = ThemeController();
    final restoredAdmin = ThemeController(adminApp: true);
    await restoredMobile.initialize();
    await restoredAdmin.initialize();
    expect(restoredMobile.mode, ThemeMode.dark);
    expect(restoredAdmin.mode, ThemeMode.light);
    for (final controller in [mobile, admin, restoredMobile, restoredAdmin]) {
      controller.dispose();
    }
  });

  testWidgets('theme button changes actual theme and its accessible label', (
    tester,
  ) async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.light);
    await tester.pumpWidget(
      ThemeScope(
        controller: controller,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => MaterialApp(
            theme: buildSafeUgTheme(brightness: Brightness.light),
            darkTheme: buildSafeUgTheme(brightness: Brightness.dark),
            themeMode: controller.mode,
            home: Scaffold(
              appBar: AppBar(actions: const [ThemeToggleButton()]),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch to light mode'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
