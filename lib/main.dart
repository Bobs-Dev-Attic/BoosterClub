// App entry point — START HERE when learning the codebase.
//
// Boot sequence:
//   1. main() tries to initialize Firebase. If the credentials in
//      lib/firebase_options.dart are still placeholders (or init fails/times
//      out), the app flips into DEMO MODE: every service swaps to an
//      in-memory data store so the whole app still works with no backend.
//   2. BoosterClubApp wires up the app-wide services with `provider`:
//        - FirestoreService  → all database reads/writes (screens never talk
//                              to Firebase directly; they go through this).
//        - AuthProvider      → who is signed in + their profile/role.
//        - ThemeProvider     → light/dark/system theme choice.
//      Any widget can reach these with context.read<T>() / context.watch<T>().
//   3. MaterialApp.router hands navigation to go_router — every URL/page is
//      declared in lib/router/app_router.dart.
//
// See README.md ("Architecture" and "How data flows") for the bigger picture.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Attempt to initialize Firebase. If credentials are still placeholders, or
  // initialization fails, fall back to demo mode so the app remains usable.
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      // Time-box init so a stalled network can never trap the app on the
      // loading splash — fall back to offline/demo data instead.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
      AppConfig.demoMode = false;
    } catch (e) {
      debugPrint('Firebase init failed, running in demo mode: $e');
      AppConfig.demoMode = true;
    }
  }

  runApp(const BoosterClubApp());
}

class BoosterClubApp extends StatelessWidget {
  const BoosterClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final router = buildRouter();

    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          routerConfig: router,
        ),
      ),
    );
  }
}
