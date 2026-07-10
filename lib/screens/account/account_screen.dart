import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/interests.dart';
import '../../models/app_user.dart';
import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Member/Supporter "My Account" area: a tabbed layout with a Dashboard
/// landing tab plus Account, Login & Security, and Preferences.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _org = TextEditingController();
  final _address = TextEditingController();

  bool _emailOptIn = true;
  final Set<String> _interests = {};
  bool _hydrated = false;
  bool _savingProfile = false;
  bool _savingPrefs = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _org.dispose();
    _address.dispose();
    super.dispose();
  }

  void _hydrate(AppUser u) {
    if (_hydrated) return;
    _name.text = u.displayName;
    _phone.text = u.phone ?? '';
    _org.text = u.organization ?? '';
    _address.text = u.address ?? '';
    _emailOptIn = u.emailOptIn;
    _interests
      ..clear()
      ..addAll(u.interests);
    _hydrated = true;
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

    return DefaultTabController(
      length: 4,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(user: user),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
                  Tab(icon: Icon(Icons.person_outline), text: 'Account'),
                  Tab(icon: Icon(Icons.lock_outline), text: 'Login & Security'),
                  Tab(icon: Icon(Icons.tune), text: 'Preferences'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _DashboardTab(user: user, interests: _interests),
                    _buildAccountTab(context, auth, user),
                    _SecurityTab(user: user),
                    _buildPreferencesTab(context, auth, user),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Account tab ------------------------------------------------------
  Widget _buildAccountTab(
      BuildContext context, AuthProvider auth, AppUser user) {
    return _TabScroll(
      children: [
        const SectionHeader(
          title: 'Contact Information',
          subtitle: 'Keep your details up to date.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  keyboardType: TextInputType.streetAddress,
                  decoration: const InputDecoration(
                    labelText: 'Mailing address',
                    prefixIcon: Icon(Icons.home_outlined),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _savingProfile
                        ? null
                        : () async {
                            setState(() => _savingProfile = true);
                            final messenger = ScaffoldMessenger.of(context);
                            await auth.updateProfile(user.copyWith(
                              displayName: _name.text.trim(),
                              phone: _phone.text.trim(),
                              address: _address.text.trim(),
                              organization: _org.text.trim(),
                            ));
                            if (!mounted) return;
                            setState(() => _savingProfile = false);
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Contact info saved.')));
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_savingProfile ? 'Saving…' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'My Committees',
          subtitle: 'Committees you\'ve been added to. Ask a Web Admin to '
              'update your memberships.',
        ),
        _MyCommittees(user: user),
      ],
    );
  }

  // ---- Preferences tab --------------------------------------------------
  Widget _buildPreferencesTab(
      BuildContext context, AuthProvider auth, AppUser user) {
    return StatefulBuilder(
      builder: (context, setLocal) {
        void toggle(String key, bool on) => setLocal(() {
              if (on) {
                _interests.add(key);
              } else {
                _interests.remove(key);
              }
            });

        return _TabScroll(
          children: [
            const SectionHeader(
              title: 'Email Preferences',
              subtitle:
                  'Choose the topics you want to hear about. We\'ll only email '
                  'you about what you pick.',
            ),
            Card(
              child: SwitchListTile(
                value: _emailOptIn,
                onChanged: (v) => setLocal(() => _emailOptIn = v),
                secondary: const Icon(Icons.mark_email_read_outlined),
                title: const Text('Receive email updates'),
                subtitle: const Text(
                    'Turn off to pause all Booster Club emails.'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Interests',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Opacity(
              opacity: _emailOptIn ? 1 : 0.5,
              child: Column(
                children: [
                  for (final g in kInterestGroups)
                    _InterestGroupTile(
                      group: g,
                      selected: _interests,
                      enabled: _emailOptIn,
                      onToggle: toggle,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingPrefs
                    ? null
                    : () async {
                        setState(() => _savingPrefs = true);
                        final messenger = ScaffoldMessenger.of(context);
                        await auth.updateProfile(user.copyWith(
                          emailOptIn: _emailOptIn,
                          interests: _interests.toList()..sort(),
                        ));
                        if (!mounted) return;
                        setState(() => _savingPrefs = false);
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Preferences saved.')));
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(_savingPrefs ? 'Saving…' : 'Save preferences'),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---- Header --------------------------------------------------------------
class _Header extends StatelessWidget {
  final AppUser user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
              ],
            ),
          ),
          Pill(user.role.label, icon: Icons.badge_outlined),
        ],
      ),
    );
  }
}

/// Scrollable padded column used inside each tab.
class _TabScroll extends StatelessWidget {
  final List<Widget> children;
  const _TabScroll({required this.children});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ---- Dashboard tab -------------------------------------------------------
class _DashboardTab extends StatelessWidget {
  final AppUser user;
  final Set<String> interests;
  const _DashboardTab({required this.user, required this.interests});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final since = user.createdAt != null
        ? DateFormat('MMMM yyyy').format(user.createdAt!)
        : '—';
    return _TabScroll(
      children: [
        Text('Welcome back, ${user.displayName.split(' ').first}! 👋',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Member since $since',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        const SizedBox(height: 20),
        StreamBuilder<List<SchoolEvent>>(
          stream: fs.events(),
          builder: (context, snap) {
            final count = snap.data?.length ?? 0;
            return Row(
              children: [
                _StatTile(
                    icon: Icons.event,
                    value: '$count',
                    label: 'Upcoming events'),
                const SizedBox(width: 12),
                _StatTile(
                    icon: Icons.tune,
                    value: '${interests.length}',
                    label: 'Interests'),
                const SizedBox(width: 12),
                _StatTile(
                    icon: Icons.badge_outlined,
                    value: user.role.label,
                    label: 'Your role'),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Quick actions',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionChip(Icons.favorite, 'Donate', () => context.go('/donate')),
            _ActionChip(Icons.volunteer_activism, 'Volunteer',
                () => context.go('/volunteering')),
            _ActionChip(Icons.event, 'Events', () => context.go('/events')),
            _ActionChip(Icons.savings, 'Fundraisers',
                () => context.go('/fundraisers')),
          ],
        ),
        const SizedBox(height: 24),
        Text('Your interests',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (interests.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('No interests set yet'),
              subtitle: const Text(
                  'Pick topics on the Preferences tab to personalize your emails.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => DefaultTabController.of(context).animateTo(3),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in interests) Pill(interestLabel(k)),
            ],
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      );
}

// ---- Preferences group tile ---------------------------------------------
class _InterestGroupTile extends StatelessWidget {
  final InterestGroup group;
  final Set<String> selected;
  final bool enabled;
  final void Function(String key, bool on) onToggle;
  const _InterestGroupTile({
    required this.group,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!group.hasSubs) {
      // Group is itself the interest.
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: selected.contains(group.key),
          onChanged: enabled ? (v) => onToggle(group.key, v ?? false) : null,
          secondary: Icon(group.icon),
          title: Text(group.label),
        ),
      );
    }
    final chosen =
        group.allSubKeys.where((k) => selected.contains(k)).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(group.icon),
        title: Text(group.label),
        subtitle: Text(chosen == 0 ? 'None selected' : '$chosen selected'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final s in group.subs)
            CheckboxListTile(
              dense: true,
              value: selected.contains(group.subKey(s)),
              onChanged: enabled
                  ? (v) => onToggle(group.subKey(s), v ?? false)
                  : null,
              title: Text(s.label),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: enabled
                    ? () {
                        final allOn = chosen == group.subs.length;
                        for (final s in group.subs) {
                          onToggle(group.subKey(s), !allOn);
                        }
                      }
                    : null,
                child: Text(
                    chosen == group.subs.length ? 'Clear all' : 'Select all'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Login & Security tab -----------------------------------------------
class _SecurityTab extends StatefulWidget {
  final AppUser user;
  const _SecurityTab({required this.user});

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  bool _busy = false;

  Future<void> _changeEmail() async {
    final controller = TextEditingController();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'New email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send verification'),
          ),
        ],
      ),
    );
    if (newEmail == null || !newEmail.contains('@')) return;
    setState(() => _busy = true);
    final res = await auth.updateEmail(newEmail);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
        content: Text(res.message ??
            (res.success ? 'Verification sent.' : 'Could not change email.'))));
  }

  Future<void> _resetPassword() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final res = await auth.sendPasswordReset(widget.user.email);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
        content: Text(res.message ??
            (res.success ? 'Password reset email sent.' : 'Failed.'))));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return _TabScroll(
      children: [
        const SectionHeader(
          title: 'Login & Security',
          subtitle: 'Manage how you sign in.',
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Email address'),
                subtitle: Text(widget.user.email),
                trailing: TextButton(
                  onPressed: _busy ? null : _changeEmail,
                  child: const Text('Change'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Password'),
                subtitle: const Text(
                    'We\'ll email you a secure reset link.'),
                trailing: TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.user.canManageAny)
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
    );
  }
}

/// Lists the committees the member belongs to (from their profile), resolved to
/// names via the live committees list.
class _MyCommittees extends StatelessWidget {
  final AppUser user;
  const _MyCommittees({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.committees.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('You\'re not on any committees yet.'),
        ),
      );
    }
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<Committee>>(
      stream: fs.committees(),
      builder: (context, snap) {
        final all = snap.data ?? const <Committee>[];
        final mine =
            all.where((c) => user.committees.contains(c.id)).toList();
        final names = mine.isEmpty
            ? user.committees // fall back to ids until they load
            : mine.map((c) => c.title).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in names) Pill(n, icon: Icons.groups_2_outlined),
              ],
            ),
          ),
        );
      },
    );
  }
}
