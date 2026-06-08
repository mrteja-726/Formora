import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formora/features/auth/presentation/auth_controller.dart';
import 'package:formora/features/auth/presentation/login_screen.dart';
import 'package:formora/features/auth/presentation/register_screen.dart';
import 'package:formora/features/profile/presentation/profile_screen.dart';
import 'package:formora/features/vault/presentation/vault_screen.dart';
import 'package:formora/features/form_automation/presentation/desktop_sync_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!loggedIn && !isLoggingIn) return '/login';
      if (loggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationShell(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
});

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  List<Widget> get _screens => [
    const ProfileScreen(),
    const VaultScreen(),
    if (_isDesktop) const DesktopSyncScreen(),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.folder_open_outlined),
      activeIcon: Icon(Icons.folder_open),
      label: 'Vault',
    ),
    if (_isDesktop)
      const BottomNavigationBarItem(
        icon: Icon(Icons.sync_alt_outlined),
        activeIcon: Icon(Icons.sync_alt),
        label: 'Desktop Sync',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    // Prevent out of bounds if switching platforms dynamically or during hot reload
    final screens = _screens;
    final currentIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF94A3B8),
        items: _navItems,
      ),
    );
  }
}
