import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/router/router.dart';
import 'package:formora/core/theme/theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FormoraApp(),
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
