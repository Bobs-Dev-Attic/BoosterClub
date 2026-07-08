import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'nav_destinations.dart';

/// App shell providing responsive navigation:
///  - Desktop / wide  : persistent NavigationRail (extended when very wide)
///  - Mobile / narrow : app bar + drawer + bottom navigation
class ResponsiveScaffold extends StatelessWidget {
  final Widget child;
  const ResponsiveScaffold({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Longest-prefix match so nested routes still highlight their section.
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < kSections.length; i++) {
      final r = kSections[i].route;
      final match = r == '/' ? location == '/' : location.startsWith(r);
      if (match && r.length > bestLen) {
        best = i;
        bestLen = r.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final selected = _selectedIndex(context);

    if (isDesktop) {
      final extended = width >= 1240;
      return Scaffold(
        body: Row(
          children: [
            _Rail(selected: selected, extended: extended),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  const _TopBar(showMenu: false),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            _Logo(size: 28),
            SizedBox(width: 8),
            Text(AppConfig.appName),
          ],
        ),
        actions: const [_AuthAction()],
      ),
      drawer: _MobileDrawer(selected: selected),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected.clamp(0, 4),
        onDestinationSelected: (i) => context.go(kSections[i].route),
        destinations: [
          for (final s in kSections.take(5))
            NavigationDestination(
              icon: Icon(s.icon),
              selectedIcon: Icon(s.selectedIcon),
              label: s.label,
            ),
        ],
      ),
    );
  }
}

/// Small "Terms · Privacy" links shown in the navigation footers.
Widget _legalLinks(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurfaceVariant;
  Widget link(String label, String route) => InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  decoration: TextDecoration.underline)),
        ),
      );
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      link('Terms', '/terms'),
      Text('·', style: TextStyle(color: color)),
      link('Privacy', '/privacy'),
    ],
  );
}

class _Rail extends StatelessWidget {
  final int selected;
  final bool extended;
  const _Rail({required this.selected, required this.extended});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height,
          maxWidth: extended ? 220 : 88,
        ),
        child: IntrinsicHeight(
          child: NavigationRail(
            extended: extended,
            selectedIndex: selected,
            groupAlignment: -1,
            onDestinationSelected: (i) => context.go(kSections[i].route),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: extended
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Logo(size: 30),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppConfig.appName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : const _Logo(size: 30),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RailFooter(extended: extended, auth: auth),
                ),
              ),
            ),
            destinations: [
              for (final s in kSections)
                NavigationRailDestination(
                  icon: Tooltip(message: s.label, child: Icon(s.icon)),
                  selectedIcon:
                      Tooltip(message: s.label, child: Icon(s.selectedIcon)),
                  label: Text(s.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  final bool extended;
  final AuthProvider auth;
  const _RailFooter({required this.extended, required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user != null && user.canManageAny)
          IconButton(
            tooltip: 'Admin dashboard',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.go('/admin'),
          ),
        if (user == null)
          extended
              ? FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                )
              : IconButton.filled(
                  tooltip: 'Sign in',
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                )
        else
          IconButton(
            tooltip: user.displayName,
            onPressed: () => context.go('/profile'),
            icon: CircleAvatar(
              radius: 16,
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
              ),
            ),
          ),
        const SizedBox(height: 8),
        ThemeToggle(compact: !extended),
        if (extended) ...[
          const SizedBox(height: 4),
          _legalLinks(context),
        ],
        const SizedBox(height: 8),
        Text(
          'v${AppConfig.appVersion}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showMenu;
  const _TopBar({required this.showMenu});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppConfig.schoolName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const _AuthAction(),
        ],
      ),
    );
  }
}

class _AuthAction extends StatelessWidget {
  const _AuthAction();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.tonalIcon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Sign in'),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: user.displayName,
      onSelected: (v) {
        switch (v) {
          case 'profile':
            context.go('/profile');
          case 'admin':
            context.go('/admin');
          case 'signout':
            auth.signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: _MenuRow(Icons.person_outline, user.displayName),
        ),
        if (user.canManageAny)
          const PopupMenuItem(
            value: 'admin',
            child: _MenuRow(Icons.admin_panel_settings_outlined, 'Admin'),
          ),
        const PopupMenuItem(
          value: 'signout',
          child: _MenuRow(Icons.logout, 'Sign out'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          radius: 16,
          child: Text(user.displayName.isNotEmpty
              ? user.displayName[0].toUpperCase()
              : '?'),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );
}

class _MobileDrawer extends StatelessWidget {
  final int selected;
  const _MobileDrawer({required this.selected});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const DrawerHeader(
              child: Row(
                children: [
                  _Logo(size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppConfig.appName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(AppConfig.schoolName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < kSections.length; i++)
                    ListTile(
                      selected: i == selected,
                      leading: Icon(i == selected
                          ? kSections[i].selectedIcon
                          : kSections[i].icon),
                      title: Text(kSections[i].label),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(kSections[i].route);
                      },
                    ),
                  if (auth.user?.canManageAny ?? false)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admin dashboard'),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin');
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (auth.user == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  auth.signOut();
                },
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ThemeToggle(compact: false),
            ),
            _legalLinks(context),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'v${AppConfig.appVersion}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light / dark / system theme switcher shown at the bottom of the navigation.
class ThemeToggle extends StatelessWidget {
  final bool compact;
  const ThemeToggle({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    const options = [
      (ThemeMode.light, Icons.light_mode, 'Light'),
      (ThemeMode.dark, Icons.dark_mode, 'Dark'),
      (ThemeMode.system, Icons.brightness_auto, 'Auto'),
    ];

    if (compact) {
      // Cycle light -> dark -> system on tap.
      final icon = switch (theme.mode) {
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.system => Icons.brightness_auto,
      };
      final next = switch (theme.mode) {
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
        ThemeMode.system => ThemeMode.light,
      };
      return IconButton(
        tooltip: 'Theme: ${theme.mode.name}',
        icon: Icon(icon),
        onPressed: () => theme.setMode(next),
      );
    }

    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final o in options)
          ButtonSegment(
            value: o.$1,
            icon: Icon(o.$2, size: 18),
            tooltip: o.$3,
          ),
      ],
      selected: {theme.mode},
      onSelectionChanged: (s) => theme.setMode(s.first),
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    // White circular backdrop so the (black line-art) crest stays visible on
    // dark surfaces and on the green hero.
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.04),
      child: Image.asset(
        'assets/images/wj_logo.png',
        fit: BoxFit.contain,
        // Graceful fallback (e.g. before the official crest is added): a green
        // badge with a wildcat paw.
        errorBuilder: (context, error, stack) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.green, AppTheme.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.pets, size: size * 0.55, color: Colors.white),
        ),
      ),
    );
  }
}
