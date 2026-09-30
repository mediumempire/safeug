import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each app remembers its own choice, following the device until one is made.
class ThemeController extends ChangeNotifier {
  ThemeController({bool adminApp = false})
    : preferenceKey = adminApp
          ? 'safeug.admin.theme_mode'
          : 'safeug.mobile.theme_mode';

  final String preferenceKey;
  ThemeMode _mode = ThemeMode.system;
  Future<SharedPreferences>? _preferences;
  bool _userChangedMode = false;
  bool _disposed = false;

  ThemeMode get mode => _mode;

  Future<SharedPreferences> _loadPreferences() =>
      _preferences ??= SharedPreferences.getInstance();

  Future<void> initialize() async {
    final preferences = await _loadPreferences();
    if (_disposed || _userChangedMode) return;
    final stored = preferences.getString(preferenceKey);
    _mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> toggle(Brightness currentBrightness) {
    final isDark = _mode == ThemeMode.system
        ? currentBrightness == Brightness.dark
        : _mode == ThemeMode.dark;
    return setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode value) async {
    if (_disposed) return;
    _userChangedMode = true;
    _mode = value;
    notifyListeners();
    final preferences = await _loadPreferences();
    if (value == ThemeMode.system) {
      await preferences.remove(preferenceKey);
    } else {
      await preferences.setString(preferenceKey, value.name);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;

  static ThemeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'A ThemeScope is required above this widget.');
    return controller!;
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () async {
        try {
          await controller.toggle(brightness);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'Theme changed. Your preference could not be saved on this device.',
                ),
              ),
            );
          }
        }
      },
    );
  }
}
