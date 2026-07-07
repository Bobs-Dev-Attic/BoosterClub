import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/account/account_screen.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/donate_screen.dart';
import '../screens/events_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/finish_signin_screen.dart';
import '../screens/funding_screen.dart';
import '../screens/fundraisers_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/meetings_screen.dart';
import '../screens/pair_screen.dart';
import '../screens/qr_login_screen.dart';
import '../screens/sponsorships_screen.dart';
import '../screens/volunteering_screen.dart';
import '../widgets/responsive_scaffold.dart';

/// Fade transition used for content pages so navigation feels smooth on web.
CustomTransitionPage _page(Widget child) => CustomTransitionPage(
      child: child,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

GoRouter buildRouter() {
  // If the app was opened via a passwordless email sign-in link, the Firebase
  // parameters arrive as query params on the launch URL — start on the finish
  // screen so we can complete sign-in.
  final base = Uri.base;
  final isEmailLink = base.queryParameters['mode'] == 'signIn' &&
      base.queryParameters.containsKey('oobCode');

  return GoRouter(
    initialLocation: isEmailLink ? '/finishSignIn' : '/',
    routes: [
      // Auth routes render full-screen (no app shell).
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/login/qr', builder: (_, __) => const QrLoginScreen()),
      GoRoute(
          path: '/finishSignIn',
          builder: (_, __) => const FinishSignInScreen()),
      GoRoute(
        path: '/pair',
        builder: (context, state) => PairScreen(
          sessionId: state.uri.queryParameters['s'] ?? '',
        ),
      ),

      // All other routes live inside the responsive shell.
      ShellRoute(
        builder: (context, state, child) =>
            ResponsiveScaffold(child: child),
        routes: [
          GoRoute(
              path: '/',
              pageBuilder: (_, __) => _page(const HomeScreen())),
          GoRoute(
              path: '/events',
              pageBuilder: (_, __) => _page(const EventsScreen())),
          GoRoute(
              path: '/volunteering',
              pageBuilder: (_, __) => _page(const VolunteeringScreen())),
          GoRoute(
              path: '/sponsorships',
              pageBuilder: (_, __) => _page(const SponsorshipsScreen())),
          GoRoute(
              path: '/donate',
              pageBuilder: (_, __) => _page(const DonateScreen())),
          GoRoute(
              path: '/funding',
              pageBuilder: (_, __) => _page(const FundingScreen())),
          GoRoute(
              path: '/fundraisers',
              pageBuilder: (_, __) => _page(const FundraisersScreen())),
          GoRoute(
              path: '/meetings',
              pageBuilder: (_, __) => _page(const MeetingsScreen())),
          GoRoute(
              path: '/gallery',
              pageBuilder: (_, __) => _page(const GalleryScreen())),
          GoRoute(
              path: '/faq', pageBuilder: (_, __) => _page(const FaqScreen())),
          GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => _page(const AccountScreen())),
          GoRoute(
              path: '/admin',
              pageBuilder: (_, __) => _page(const AdminScreen())),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Page not found: ${state.uri}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  );
}
