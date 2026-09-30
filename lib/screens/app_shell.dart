import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'dashboard_screen.dart';
import 'emergency_screen.dart';
import 'report_screen.dart';
import 'safety_screen.dart';
import 'admin_screen.dart';
import '../services/firestore_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});
  final User user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final _adminRole = FirestoreService().roleStream('roles_admin', widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(stream: _adminRole, builder: (context, snapshot) {
      if (snapshot.data == true) return const AdminScreen();
      return _mobileShell(context);
    });
  }

  Widget _mobileShell(BuildContext context) {
    final pages = [
      DashboardScreen(user: widget.user),
      const SafetyScreen(),
      ReportScreen(user: widget.user),
      const EmergencyScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_index == 0)
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            if (_index == 0) const SizedBox(width: 8),
            Text(
              'SafeUG',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Theme',
            onPressed: () =>
                showSafeSnackBar(context, 'Theme follows your device setting.'),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) async {
              if (value == 'signout') await FirebaseAuth.instance.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'account',
                enabled: false,
                child: Text(
                  widget.user.isAnonymous
                      ? 'Guest account'
                      : widget.user.email ?? 'SafeUG account',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withValues(alpha: .12),
              child: Text(
                (widget.user.displayName?.isNotEmpty == true
                        ? widget.user.displayName![0]
                        : 'U')
                    .toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_gmailerrorred_outlined),
            selectedIcon: Icon(Icons.report_gmailerrorred_rounded),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}
