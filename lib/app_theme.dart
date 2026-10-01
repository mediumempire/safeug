import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF00684B);
  static const background = Color(0xFFF3F7F6);
  static const accent = Color(0xFF21AF77);
  static const ink = Color(0xFF142D29);
  static const muted = Color(0xFF61788D);
  static const danger = Color(0xFFD92D3A);
}

ThemeData buildSafeUgTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: isDark ? const Color(0xFF78DCB2) : AppColors.primary,
    secondary: isDark ? const Color(0xFF92E6BB) : AppColors.accent,
    surface: isDark ? const Color(0xFF122333) : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0B1722)
        : AppColors.background,
    fontFamily: 'Manrope',
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF0B1722) : AppColors.background,
      foregroundColor: isDark ? Colors.white : AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF122333) : Colors.white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A3043) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF122333) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

const safeUgLogoAsset = 'assets/branding/safeug-logo.png';

class SafeUgLogo extends StatelessWidget {
  const SafeUgLogo({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          safeUgLogoAsset,
          width: large ? 72 : 44,
          height: large ? 72 : 44,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 10),
        Text(
          'SafeUG',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: large ? 31 : 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

void showSafeSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
