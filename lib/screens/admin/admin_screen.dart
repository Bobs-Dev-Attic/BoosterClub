import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/local_history.dart';
import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/history_suggestions_service.dart';
import '../../widgets/common.dart';
import 'content_forms.dart';
import 'donations_admin.dart';
import 'event_import.dart';
import 'users_admin.dart';

/// Admin dashboard. Visible to Administrators and Web Admins. Lets managers
/// create, edit and delete content across every collection.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null || !user.canManageAny) {
      return PageBody(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: 40),
            const EmptyState(
              icon: Icons.lock_outline,
              message:
                  'You don\'t have permission to manage any part of the site.',
            ),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      );
    }

    // Only show the tabs the user is permitted to manage.
    bool can(String p) => user.can(p);
    final tabs = <_AdminTab>[
      if (can('manage_events'))
        _AdminTab('Events', Icons.event, (fs) => _EventsAdmin(fs)),
      if (can('manage_volunteering'))
        _AdminTab('Volunteering', Icons.volunteer_activism,
            (fs) => _VolunteerAdmin(fs)),
      if (can('manage_sponsorships'))
        _AdminTab('Sponsors', Icons.handshake, (fs) => _SponsorAdmin(fs)),
      if (can('manage_funding'))
        _AdminTab('Funding', Icons.request_quote, (fs) => _FundingAdmin(fs)),
      if (can('manage_fundraisers'))
        _AdminTab('Fundraisers', Icons.savings, (fs) => _FundraiserAdmin(fs)),
      if (can('manage_meetings'))
        _AdminTab('Meetings', Icons.groups, (fs) => _MeetingAdmin(fs)),
      if (can('manage_faqs'))
        _AdminTab('FAQ', Icons.help, (fs) => _FaqAdmin(fs)),
      if (can('manage_history'))
        _AdminTab('History', Icons.auto_stories, (fs) => _HistoryAdmin(fs)),
      if (can('manage_gallery'))
        _AdminTab('Gallery', Icons.photo_library, (fs) => _GalleryAdmin(fs)),
      if (can('manage_donations'))
        _AdminTab('Donations', Icons.favorite, (fs) => DonationsAdmin(fs: fs)),
      if (can('manage_users')) ...[
        _AdminTab('Users & Roles', Icons.manage_accounts,
            (fs) => UsersAdmin(fs: fs, actor: user)),
        _AdminTab('Audit Log', Icons.history, (fs) => AuditLogView(fs: fs)),
      ],
    ];

    final fs = context.read<FirestoreService>();
    if (tabs.isEmpty) {
      return const PageBody(
        maxWidth: 480,
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: EmptyState(
              icon: Icons.info_outline,
              message: 'You have no manageable sections assigned yet.'),
        ),
      );
    }
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
                      if (user.can('seed_content')) ...[
                        _SeedButton(fs: fs),
                        const SizedBox(width: 12),
                      ],
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
  final Widget? extraAction;
  const _AdminList({
    required this.collection,
    required this.stream,
    required this.fs,
    required this.subtitle,
    required this.editor,
    this.extraAction,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (extraAction != null) ...[
                extraAction!,
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Add new'),
              ),
            ],
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
        extraAction: OutlinedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => EventImportDialog(fs: fs),
          ),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Import CSV'),
        ),
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

class _HistoryAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _HistoryAdmin(this.fs);

  static final _md = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) => _AdminList<HistoryFact>(
        collection: 'history_facts',
        stream: fs.historyFacts(),
        fs: fs,
        subtitle: (h) =>
            '${_md.format(DateTime(2000, h.month, h.day))}'
            '${h.year != null ? ', ${h.year}' : ''} · ${h.fact}',
        editor: editHistoryFact,
        extraAction: Wrap(
          spacing: 8,
          children: [
            _LocalPackButton(fs: fs),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _OnThisDayDialog(fs: fs),
              ),
              icon: const Icon(Icons.travel_explore, size: 18),
              label: const Text('On This Day'),
            ),
          ],
        ),
      );
}

class _GalleryAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _GalleryAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<GalleryImage>(
        collection: 'gallery',
        stream: fs.gallery(),
        fs: fs,
        subtitle: (g) => g.caption.isNotEmpty
            ? g.caption
            : (g.tags.isNotEmpty ? g.tags.join(', ') : 'No caption'),
        editor: (context, existing) => editGalleryImage(context, existing, fs),
      );
}

/// One-click import of the built-in local Bethesda / Montgomery County / WJ
/// history pack. Skips facts that already exist (matched by id).
class _LocalPackButton extends StatefulWidget {
  final FirestoreService fs;
  const _LocalPackButton({required this.fs});

  @override
  State<_LocalPackButton> createState() => _LocalPackButtonState();
}

class _LocalPackButtonState extends State<_LocalPackButton> {
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existing = await widget.fs.historyFacts().first;
      final ids = existing.map((e) => e.id).toSet();
      var added = 0;
      for (final f in LocalHistory.pack()) {
        if (ids.contains(f.id)) continue;
        await widget.fs.upsert('history_facts', f);
        added++;
      }
      messenger.showSnackBar(SnackBar(
          content: Text(added == 0
              ? 'Local history pack already imported.'
              : 'Added $added local history fact(s).')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _busy ? null : _import,
        icon: _busy
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.place, size: 18),
        label: const Text('Local pack'),
      );
}

/// Pulls "On This Day" suggestions from an external feed for a chosen date and
/// lets a Contributor turn one into a local history fact.
class _OnThisDayDialog extends StatefulWidget {
  final FirestoreService fs;
  const _OnThisDayDialog({required this.fs});

  @override
  State<_OnThisDayDialog> createState() => _OnThisDayDialogState();
}

class _OnThisDayDialogState extends State<_OnThisDayDialog> {
  final _svc = HistorySuggestionsService();
  DateTime _date = DateTime.now();
  bool _marylandOnly = false;
  bool _loading = false;
  bool _fetched = false;
  List<OnThisDayEvent> _events = const [];

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final events =
        await _svc.fetch(_date.month, _date.day, marylandOnly: _marylandOnly);
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
      _fetched = true;
    });
  }

  Future<void> _use(OnThisDayEvent e) async {
    final seeded = HistoryFact(
      id: 'new',
      title: 'On this day, ${e.year ?? ''}'.trim(),
      fact: e.description,
      month: _date.month,
      day: _date.day,
      year: e.year,
      sourceUrl: e.wikipediaUrl,
    );
    final saved = await editHistoryFact(context, seeded);
    if (saved != null) {
      await widget.fs.upsert('history_facts', saved);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('History fact added.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('On This Day — suggestions'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'General world/US history from a public feed (Wikipedia-based). '
              'There is no dedicated Bethesda/WJ history API — use the “Maryland '
              'only” filter to spot local ties, or the Local pack button for '
              'built-in local facts.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(
                            DateTime.now().year, _date.month, _date.day),
                        firstDate: DateTime(DateTime.now().year, 1, 1),
                        lastDate: DateTime(DateTime.now().year, 12, 31),
                      );
                      if (picked != null) {
                        setState(() => _date =
                            DateTime(2000, picked.month, picked.day));
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                        isDense: true,
                      ),
                      child: Text(DateFormat('MMMM d').format(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _fetch,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Fetch'),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Maryland / Montgomery County only'),
              value: _marylandOnly,
              onChanged: (v) => setState(() => _marylandOnly = v),
            ),
            const Divider(),
            Expanded(
              child: !_fetched
                  ? const Center(
                      child: Text('Pick a date and tap Fetch.'))
                  : _events.isEmpty
                      ? const Center(
                          child: Text(
                              'No suggestions (feed unreachable or nothing '
                              'matched the filter). You can still add a fact '
                              'manually.',
                              textAlign: TextAlign.center))
                      : ListView.separated(
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _events[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  '${e.year != null ? '${e.year} — ' : ''}${e.description}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              trailing: TextButton(
                                onPressed: () => _use(e),
                                child: const Text('Use'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
