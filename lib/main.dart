import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
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
      ],
      child: MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
