// lib/main.dart
//
// App entry point.
// Initialises Hive and the database before runApp.
// No user accounts, no server connections.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:formora/core/database/app_database.dart';
import 'package:formora/core/storage/hive_storage.dart';
import 'package:formora/core/router/router.dart';
import 'package:formora/core/theme/theme.dart';
import 'package:formora/core/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait + landscape (allow both)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialise Hive CE (settings, ai config)
  final hive = HiveStorage();
  await hive.init();

  // Open Drift database (SQLite)
  final db = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        // Inject the already-opened database so the provider doesn't
        // open a second instance.
        appDatabaseProvider.overrideWithValue(db),
        hiveStorageProvider.overrideWithValue(hive),
      ],
      child: const FormoraApp(),
    ),
  );
}

class FormoraApp extends ConsumerWidget {
  const FormoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Formora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,

      // Accessibility & Localizations
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],

      // Semantic label for screen readers
      builder: (context, child) {
        // Ensure text never scales beyond 1.3x for layout integrity
        // (accessibility still works via 1.3x, which is still large)
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
