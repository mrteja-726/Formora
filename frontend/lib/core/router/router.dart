import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:formora/features/auth/presentation/splash_screen.dart';
import 'package:formora/features/auth/presentation/welcome_screen.dart';
import 'package:formora/features/profile/presentation/profile_wizard_screens.dart';
import 'package:formora/features/profile/presentation/profile_screen.dart';
import 'package:formora/features/vault/presentation/vault_screen.dart';
import 'package:formora/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:formora/features/ai_chat/presentation/ai_provider_setup_screen.dart';
import 'package:formora/features/backup/presentation/backup_center_screen.dart';
import 'package:formora/features/settings/presentation/settings_page.dart';
import 'package:formora/features/achievements/presentation/achievements_screen.dart';
import 'package:formora/features/support/presentation/support_center_screen.dart';
import 'package:formora/core/security/app_lock_screen.dart';

// Route path constants
class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const home = '/dashboard';
  static const profiles = '/profiles';
  static const profileDetail = '/profiles/:id';
  static const profileCreate = '/profiles/create';
  static const documents = '/documents';
  static const documentDetail = '/documents/:id';
  static const documentUpload = '/documents/upload';
  static const aiChat = '/ai-chat';
  static const aiChatConversation = '/ai-chat/:conversationId';
  static const backup = '/backup';
  static const settings = '/settings';
  static const settingsAi = '/settings/ai';
  static const achievements = '/achievements';
  static const support = '/support';
  static const appLock = '/lock';

  // Helpers
  static String profileDetailPath(String id) => '/profiles/$id';
  static String documentDetailPath(String id) => '/documents/$id';
  static String aiConversationPath(String id) => '/ai-chat/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      // ── Splash Screen (Top Level) ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Welcome Screen (Top Level) ────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // ── Profile Creation Wizard (Top Level) ───────────────────────────
      GoRoute(
        path: AppRoutes.profileCreate,
        name: 'profileCreate',
        builder: (context, state) => const ProfileWizardScreen(),
      ),

      // ── App Lock Screen (Top Level) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.appLock,
        name: 'appLock',
        builder: (context, state) => const AppLockScreen(),
      ),

      // ── Main Shell with bottom navigation ──────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.documents,
            name: 'documents',
            builder: (context, state) => const VaultScreen(),
          ),
          GoRoute(
            path: AppRoutes.aiChat,
            name: 'aiChat',
            builder: (context, state) => const AiChatScreen(),
            routes: [
              GoRoute(
                path: ':conversationId',
                name: 'aiChatConversation',
                builder: (context, state) {
                  final id = state.pathParameters['conversationId']!;
                  return AiChatScreen(conversationId: id);
                },
              ),
            ],
          ),
          // Additional settings pages or sub-tabs
          GoRoute(
            path: AppRoutes.backup,
            name: 'backup',
            builder: (context, state) => const BackupCenterScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'ai',
                name: 'settingsAi',
                builder: (context, state) => const AiProviderSetupScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.achievements,
            name: 'achievements',
            builder: (context, state) => const AchievementsScreen(),
          ),
          GoRoute(
            path: AppRoutes.support,
            name: 'support',
            builder: (context, state) => const SupportCenterScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
});

// ── Navigation Shell ───────────────────────────────────────────────────────

class MainNavigationShell extends StatefulWidget {
  final Widget child;
  const MainNavigationShell({super.key, required this.child});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final List<_NavItem> _items = const [
    _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', route: AppRoutes.home),
    _NavItem(icon: Icons.folder_open_outlined, activeIcon: Icons.folder, label: 'Documents', route: AppRoutes.documents),
    _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'AI', route: AppRoutes.aiChat),
    _NavItem(icon: Icons.backup_outlined, activeIcon: Icons.backup, label: 'Backup', route: AppRoutes.backup),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', route: AppRoutes.settings),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = _items.length - 1; i >= 0; i--) {
      if (location.startsWith(_items[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_items[i].route),
        destinations: _items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
