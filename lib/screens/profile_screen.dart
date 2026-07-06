import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _org = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _org.dispose();
    super.dispose();
  }

  void _hydrate(AppUser user) {
    if (_loaded) return;
    _name.text = user.displayName;
    _phone.text = user.phone ?? '';
    _org.text = user.organization ?? '';
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return PageBody(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: 40),
            const EmptyState(
                icon: Icons.lock_outline,
                message: 'Please sign in to view your account.'),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }
    _hydrate(user);

    return PageBody(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
              title: 'My Account', icon: Icons.person_outline),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName,
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            Text(user.email,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 6),
                            Pill(user.role.label, icon: Icons.badge_outlined),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _org,
                    decoration: const InputDecoration(
                      labelText: 'Organization (for sponsors)',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await auth.updateProfile(user.copyWith(
                              displayName: _name.text.trim(),
                              phone: _phone.text.trim(),
                              organization: _org.text.trim(),
                            ));
                            if (!context.mounted) return;
                            setState(() => _saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile saved.')),
                            );
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (user.role.canManageContent)
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin dashboard'),
                subtitle: const Text('Manage app content'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin'),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
