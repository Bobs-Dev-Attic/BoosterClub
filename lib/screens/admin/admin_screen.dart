import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';
import 'content_forms.dart';

/// Admin dashboard. Visible to Administrators and Web Admins. Lets managers
/// create, edit and delete content across every collection.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null || !user.role.canManageContent) {
      return PageBody(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: 40),
            const EmptyState(
              icon: Icons.lock_outline,
              message:
                  'You need Administrator access to view this page.',
            ),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      );
    }

    final tabs = <_AdminTab>[
      _AdminTab('Events', Icons.event, (fs) => _EventsAdmin(fs)),
      _AdminTab('Volunteering', Icons.volunteer_activism,
          (fs) => _VolunteerAdmin(fs)),
      _AdminTab('Sponsors', Icons.handshake, (fs) => _SponsorAdmin(fs)),
      _AdminTab('Funding', Icons.request_quote, (fs) => _FundingAdmin(fs)),
      _AdminTab('Fundraisers', Icons.savings, (fs) => _FundraiserAdmin(fs)),
      _AdminTab('Meetings', Icons.groups, (fs) => _MeetingAdmin(fs)),
      _AdminTab('FAQ', Icons.help, (fs) => _FaqAdmin(fs)),
    ];

    final fs = context.read<FirestoreService>();
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text('Admin Dashboard',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      _SeedButton(fs: fs),
                      const SizedBox(width: 12),
                      Pill(user.role.label, icon: Icons.badge_outlined),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final t in tabs)
                      Tab(icon: Icon(t.icon, size: 20), text: t.label),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [for (final t in tabs) t.build(fs)],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  final Widget Function(FirestoreService) build;
  _AdminTab(this.label, this.icon, this.build);
}

/// Populates every collection with the bundled sample content — handy for a
/// fresh database. Shows a confirmation and a progress indicator.
class _SeedButton extends StatefulWidget {
  final FirestoreService fs;
  const _SeedButton({required this.fs});

  @override
  State<_SeedButton> createState() => _SeedButtonState();
}

class _SeedButtonState extends State<_SeedButton> {
  bool _busy = false;

  Future<void> _seed() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.auto_awesome),
        title: const Text('Load sample content?'),
        content: const Text(
          'This adds a starter set of events, volunteer opportunities, '
          'sponsorship tiers, fundraisers, meetings and FAQs. Existing items '
          'with the same IDs are overwritten; your other content is untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load content'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.fs.seedSampleData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sample content loaded.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load content: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _seed,
      icon: _busy
          ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome, size: 18),
      label: Text(_busy ? 'Loading…' : 'Load sample content'),
    );
  }
}

/// Shared scaffold for an admin list: a header with an add button, and a list
/// of items with edit/delete actions.
class _AdminList<T extends ContentItem> extends StatelessWidget {
  final String collection;
  final Stream<List<T>> stream;
  final FirestoreService fs;
  final String Function(T) subtitle;
  final Future<T?> Function(BuildContext, T?) editor;
  const _AdminList({
    required this.collection,
    required this.stream,
    required this.fs,
    required this.subtitle,
    required this.editor,
  });

  Future<void> _edit(BuildContext context, T? existing) async {
    final result = await editor(context, existing);
    if (result != null) {
      await fs.upsert(collection, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add new'),
            ),
          ),
          const SizedBox(height: 12),
          StreamListView<T>(
            stream: stream,
            emptyMessage: 'No items yet — add one to get started.',
            builder: (context, items) => Column(
              children: [
                for (final item in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(subtitle(item),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(context, item),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, item),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, T item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('“${item.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await fs.delete(collection, item.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---- Per-collection admin lists -----------------------------------------

class _EventsAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _EventsAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<SchoolEvent>(
        collection: 'events',
        stream: fs.events(),
        fs: fs,
        subtitle: (e) => e.description,
        editor: editEvent,
      );
}

class _VolunteerAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _VolunteerAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<VolunteerOpportunity>(
        collection: 'volunteering',
        stream: fs.volunteering(),
        fs: fs,
        subtitle: (o) =>
            '${o.description}  ·  ${o.spotsFilled}/${o.spotsNeeded} filled',
        editor: editVolunteer,
      );
}

class _SponsorAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _SponsorAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<Sponsorship>(
        collection: 'sponsorships',
        stream: fs.sponsorships(),
        fs: fs,
        subtitle: (s) => '${s.tier} · \$${s.amount.toStringAsFixed(0)}',
        editor: editSponsorship,
      );
}

class _FundingAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _FundingAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<FundingRequest>(
        collection: 'funding_requests',
        stream: fs.fundingRequests(),
        fs: fs,
        subtitle: (r) =>
            '${r.status.toUpperCase()} · \$${r.amountRequested.toStringAsFixed(0)}',
        editor: editFunding,
      );
}

class _FundraiserAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _FundraiserAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<FundraisingEvent>(
        collection: 'fundraisers',
        stream: fs.fundraisers(),
        fs: fs,
        subtitle: (f) =>
            '\$${f.raisedAmount.toStringAsFixed(0)} / \$${f.goalAmount.toStringAsFixed(0)}',
        editor: editFundraiser,
      );
}

class _MeetingAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _MeetingAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<Meeting>(
        collection: 'meetings',
        stream: fs.meetings(),
        fs: fs,
        subtitle: (m) => m.meetingDate != null
            ? DateFormat('MMM d, yyyy').format(m.meetingDate!)
            : m.description,
        editor: editMeeting,
      );
}

class _FaqAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _FaqAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<FaqItem>(
        collection: 'faqs',
        stream: fs.faqs(),
        fs: fs,
        subtitle: (q) => q.answer,
        editor: editFaq,
      );
}
