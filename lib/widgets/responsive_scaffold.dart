import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
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
                  _TopBar(showMenu: false),
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
        title: Row(
          children: [
            const _Logo(size: 28),
            const SizedBox(width: 8),
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
                  icon: Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
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
        if (user != null && user.role.canManageContent)
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
        if (user.role.canManageContent)
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
                  if (auth.user?.role.canManageContent ?? false)
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
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A54), Color(0xFF1E4A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        '🦁',
        style: TextStyle(fontSize: size * 0.55),
      ),
    );
  }
}
