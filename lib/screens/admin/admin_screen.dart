import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/demo_data.dart';
import '../../data/local_history.dart';
import '../../models/app_user.dart';
import '../../models/content_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/history_suggestions_service.dart';
import '../../widgets/common.dart';
import 'content_forms.dart';
import 'donations_admin.dart';
import 'event_import.dart';
import 'fundraising_admin.dart';
import 'gallery_admin.dart';
import 'users_admin.dart';

/// The top-level groupings shown on the Admin Dashboard. Each category collects
/// a set of related management sections and is rendered as a flyout menu, so the
/// dozen-plus sections are organised by topic instead of one long tab strip.
enum _AdminCategory {
  content('Content & Engagement', Icons.dashboard_customize),
  fundraising('Fundraising & Finance', Icons.savings),
  organization('Organization', Icons.account_balance);

  const _AdminCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Admin dashboard. Visible to Administrators and Web Admins. Lets managers
/// create, edit and delete content across every collection.
///
/// Sections are grouped into a small row of [_AdminCategory] flyout menus rather
/// than a single long row of tabs. Tapping a category opens a menu of the
/// related sections; the chosen one is shown below. It's a [StatefulWidget]
/// because it has to remember which section is currently open.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // The label of the currently open section. Null until the user picks one, in
  // which case we fall back to the first section they're allowed to see. We key
  // off the label (not the object) so it survives the list being rebuilt.
  String? _selectedLabel;

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

    // Only build the sections the user is permitted to manage. Each carries the
    // category it belongs to; they're declared grouped by category so the menus
    // and their items keep this order.
    bool can(String p) => user.can(p);
    final tabs = <_AdminTab>[
      // Content & Engagement — the public-facing pages members browse.
      if (can('manage_events'))
        _AdminTab('Events', Icons.event, _AdminCategory.content,
            (fs) => _EventsAdmin(fs)),
      if (can('manage_volunteering'))
        _AdminTab('Volunteering', Icons.volunteer_activism,
            _AdminCategory.content, (fs) => _VolunteerAdmin(fs)),
      if (can('manage_faqs'))
        _AdminTab('FAQ', Icons.help, _AdminCategory.content,
            (fs) => _FaqAdmin(fs)),
      if (can('manage_gallery'))
        _AdminTab('Gallery', Icons.photo_library, _AdminCategory.content,
            (fs) => GalleryAdmin(fs: fs)),
      if (can('manage_history'))
        _AdminTab('History', Icons.auto_stories, _AdminCategory.content,
            (fs) => _HistoryAdmin(fs)),
      // Fundraising & Finance — everything that brings in or tracks money.
      if (can('manage_sponsorships'))
        _AdminTab('Sponsors', Icons.handshake, _AdminCategory.fundraising,
            (fs) => _SponsorAdmin(fs)),
      if (can('manage_funding'))
        _AdminTab('Funding', Icons.request_quote, _AdminCategory.fundraising,
            (fs) => _FundingAdmin(fs)),
      if (can('manage_fundraisers'))
        _AdminTab('Fundraisers', Icons.savings, _AdminCategory.fundraising,
            (fs) => _FundraiserAdmin(fs)),
      if (can('manage_fundraising') ||
          can('fulfill_fundraising') ||
          can('supply_fundraising') ||
          can('sponsor_fundraising'))
        _AdminTab('Fundraising', Icons.campaign, _AdminCategory.fundraising,
            (fs) => FundraisingAdmin(fs: fs, user: user)),
      if (can('manage_donations'))
        _AdminTab('Donations', Icons.favorite, _AdminCategory.fundraising,
            (fs) => DonationsAdmin(fs: fs)),
      // Organization — governance, people and legal.
      if (can('manage_meetings'))
        _AdminTab('Meetings', Icons.groups, _AdminCategory.organization,
            (fs) => _MeetingAdmin(fs)),
      if (can('manage_committees')) ...[
        _AdminTab('Committees', Icons.groups_2, _AdminCategory.organization,
            (fs) => _CommitteeAdmin(fs)),
        _AdminTab('Teams', Icons.diversity_3, _AdminCategory.organization,
            (fs) => _TeamsAdmin(fs)),
      ],
      if (can('manage_legal'))
        _AdminTab('Legal', Icons.gavel, _AdminCategory.organization,
            (fs) => _LegalAdmin(fs)),
      if (can('manage_users')) ...[
        _AdminTab('Users & Roles', Icons.manage_accounts,
            _AdminCategory.organization, (fs) => UsersAdmin(fs: fs, actor: user)),
        _AdminTab('Audit Log', Icons.history, _AdminCategory.organization,
            (fs) => AuditLogView(fs: fs)),
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

    // Bucket the permitted sections by category (preserving declaration order).
    final byCategory = <_AdminCategory, List<_AdminTab>>{};
    for (final t in tabs) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    // Resolve the open section, defaulting to the first one available.
    final selected = tabs.firstWhere(
      (t) => t.label == _selectedLabel,
      orElse: () => tabs.first,
    );

    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('Admin Dashboard', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (user.can('seed_content')) ...[
                      _SeedButton(fs: fs),
                      const SizedBox(width: 12),
                    ],
                    Pill(user.role.label, icon: Icons.badge_outlined),
                  ],
                ),
              ),
              // Row of category flyout menus. Wraps to new lines on narrow
              // screens rather than scrolling off the edge.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in _AdminCategory.values)
                      if (byCategory[category] != null)
                        _CategoryMenu(
                          category: category,
                          tabs: byCategory[category]!,
                          selectedLabel: selected.label,
                          onSelected: (t) =>
                              setState(() => _selectedLabel = t.label),
                        ),
                  ],
                ),
              ),
              // Breadcrumb showing which section is open now that the flyouts
              // collapse after a choice is made.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  children: [
                    Icon(selected.icon,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(selected.label,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        Expanded(
          // Key by label so switching sections tears down the old panel and
          // builds the new one fresh instead of trying to reuse its state.
          child: KeyedSubtree(
            key: ValueKey(selected.label),
            child: selected.build(fs),
          ),
        ),
      ],
    );
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  final _AdminCategory category;
  final Widget Function(FirestoreService) build;
  _AdminTab(this.label, this.icon, this.category, this.build);
}

/// A single category button that opens a flyout ([MenuAnchor]) listing the
/// sections in that category. The button is highlighted while the open section
/// belongs to it, and the current section is ticked in the menu.
class _CategoryMenu extends StatelessWidget {
  final _AdminCategory category;
  final List<_AdminTab> tabs;
  final String selectedLabel;
  final ValueChanged<_AdminTab> onSelected;
  const _CategoryMenu({
    required this.category,
    required this.tabs,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // True when the open section lives in this category — used to highlight it.
    final active = tabs.any((t) => t.label == selectedLabel);
    return MenuAnchor(
      menuChildren: [
        for (final t in tabs)
          MenuItemButton(
            leadingIcon: Icon(t.icon,
                size: 20, color: t.label == selectedLabel ? scheme.primary : null),
            trailingIcon: t.label == selectedLabel
                ? Icon(Icons.check, size: 18, color: scheme.primary)
                : null,
            onPressed: () => onSelected(t),
            child: Text(
              t.label,
              style: t.label == selectedLabel
                  ? TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600)
                  : null,
            ),
          ),
      ],
      builder: (context, controller, child) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final icon = Icon(category.icon, size: 18);
        final label = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.label),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        );
        return active
            ? FilledButton.tonalIcon(
                onPressed: toggle, icon: icon, label: label)
            : OutlinedButton.icon(
                onPressed: toggle, icon: icon, label: label);
      },
    );
  }
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

  /// Optional extra action shown before Edit/Delete on each row (e.g. a
  /// "Manage members" button for committees and teams).
  final Widget Function(BuildContext, T)? itemLeadingAction;
  const _AdminList({
    required this.collection,
    required this.stream,
    required this.fs,
    required this.subtitle,
    required this.editor,
    this.extraAction,
    this.itemLeadingAction,
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
                          if (itemLeadingAction != null)
                            itemLeadingAction!(context, item),
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

class _CommitteeAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _CommitteeAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<Committee>(
        collection: 'committees',
        stream: fs.committees(),
        fs: fs,
        subtitle: (c) => c.roles.isEmpty
            ? (c.summary)
            : '${c.roles.length} role${c.roles.length == 1 ? '' : 's'} · '
                '${c.roles.take(3).map((r) => r.title).join(', ')}'
                '${c.roles.length > 3 ? '…' : ''}',
        editor: editCommittee,
        itemLeadingAction: (context, c) => TextButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _CommitteeMembersDialog(fs: fs, committee: c),
          ),
          icon: const Icon(Icons.group_add, size: 18),
          label: const Text('Members'),
        ),
      );
}

class _TeamsAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _TeamsAdmin(this.fs);
  @override
  Widget build(BuildContext context) => _AdminList<Team>(
        collection: 'teams',
        stream: fs.teams(),
        fs: fs,
        subtitle: (t) => t.description.isEmpty ? 'Team' : t.description,
        editor: editTeam,
        itemLeadingAction: (context, t) => TextButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => _TeamMembersDialog(fs: fs, team: t),
          ),
          icon: const Icon(Icons.group_add, size: 18),
          label: const Text('Members'),
        ),
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

/// Manages the two canonical legal documents (Terms, Privacy). Always shows
/// both; if one hasn't been published yet, a starter template is offered so the
/// Policy Admin can edit and publish it.
class _LegalAdmin extends StatelessWidget {
  final FirestoreService fs;
  const _LegalAdmin(this.fs);

  static const _knownIds = ['terms', 'privacy'];

  LegalDocument _template(String id) =>
      DemoData.legalDocuments().firstWhere((d) => d.id == id);

  Future<void> _edit(BuildContext context, LegalDocument doc) async {
    final result = await editLegalDocument(context, doc);
    if (result != null) await fs.upsert('legal_documents', result);
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            'Terms of Use and Privacy Policy. Changes publish immediately to the '
            'public Terms and Privacy pages. These are starter drafts — replace '
            'every [PLACEHOLDER] and have an attorney review before relying on them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LegalDocument>>(
            stream: fs.legalDocuments(),
            builder: (context, snap) {
              final existing = {
                for (final d in (snap.data ?? const <LegalDocument>[])) d.id: d
              };
              return Column(
                children: [
                  for (final id in _knownIds)
                    _LegalCard(
                      doc: existing[id] ?? _template(id),
                      published: existing.containsKey(id),
                      onEdit: (doc) => _edit(context, doc),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final LegalDocument doc;
  final bool published;
  final void Function(LegalDocument) onEdit;
  const _LegalCard(
      {required this.doc, required this.published, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final updated = doc.updatedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.gavel),
        title: Text(doc.title),
        subtitle: Text(published
            ? (updated != null
                ? 'Published · updated ${DateFormat('MMM d, y').format(updated)}'
                : 'Published')
            : 'Not published yet — a starter template is ready to edit'),
        trailing: FilledButton.icon(
          onPressed: () => onEdit(doc),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        isThreeLine: false,
      ),
    );
  }
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

// ===========================================================================
// Committee & Team membership managers
//
// Membership lives in dedicated join collections (committee_members,
// team_members) rather than on the user document, so these dialogs read/write
// those records directly via FirestoreService.
// ===========================================================================

/// Shows a searchable list of app users to add, excluding those already in the
/// group. Returns the chosen user, or null if cancelled.
Future<AppUser?> _pickUser(
    BuildContext context, FirestoreService fs, Set<String> excludeIds) {
  return showDialog<AppUser>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add a member'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: StreamBuilder<List<AppUser>>(
          stream: fs.users(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = (snap.data ?? const <AppUser>[])
                .where((u) => !excludeIds.contains(u.uid))
                .toList();
            if (users.isEmpty) {
              return const Center(child: Text('No more users to add.'));
            }
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(u.displayName),
                  subtitle: Text(u.email),
                  onTap: () => Navigator.pop(context, u),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

/// Checkbox picker for the committee roles a member holds.
Future<void> _editCommitteeMemberRoles(BuildContext context,
    FirestoreService fs, Committee committee, CommitteeMember member) async {
  final selected = {...member.roleIds};
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text('Roles — ${member.userName}'),
        content: SizedBox(
          width: 400,
          child: committee.roles.isEmpty
              ? const Text(
                  'This committee has no roles yet. Add roles by editing the '
                  'committee, then assign them here.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in committee.roles)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(r.id),
                          title: Text(r.title),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selected.add(r.id);
                            } else {
                              selected.remove(r.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    await fs.setCommitteeMemberRoles(member, selected.toList());
  }
}

/// Lists a committee's members, with add / edit-roles / remove actions.
class _CommitteeMembersDialog extends StatelessWidget {
  final FirestoreService fs;
  final Committee committee;
  const _CommitteeMembersDialog({required this.fs, required this.committee});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Members — ${committee.title}'),
      content: SizedBox(
        width: 520,
        height: 440,
        child: StreamBuilder<List<CommitteeMember>>(
          stream: fs.committeeMembers(),
          builder: (context, snap) {
            final members = (snap.data ?? const <CommitteeMember>[])
                .where((m) => m.committeeId == committee.id)
                .toList()
              ..sort((a, b) => a.userName
                  .toLowerCase()
                  .compareTo(b.userName.toLowerCase()));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final existing = {for (final m in members) m.userId};
                      final user = await _pickUser(context, fs, existing);
                      if (user != null) {
                        await fs.addCommitteeMember(committee, user);
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add member'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text('No members yet.'))
                      : ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final m = members[i];
                            final roleTitles = [
                              for (final id in m.roleIds)
                                committee.roleById(id)?.title,
                            ].whereType<String>().toList();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.userName),
                              subtitle: Text(roleTitles.isEmpty
                                  ? 'No role assigned'
                                  : roleTitles.join(', ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit roles',
                                    icon: const Icon(Icons.badge_outlined),
                                    onPressed: () => _editCommitteeMemberRoles(
                                        context, fs, committee, m),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    icon:
                                        const Icon(Icons.person_remove_outlined),
                                    onPressed: () => fs.removeCommitteeMember(m),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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

/// Lists a team's members, with add / remove actions.
class _TeamMembersDialog extends StatelessWidget {
  final FirestoreService fs;
  final Team team;
  const _TeamMembersDialog({required this.fs, required this.team});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Members — ${team.title}'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: StreamBuilder<List<TeamMember>>(
          stream: fs.teamMembers(),
          builder: (context, snap) {
            final members = (snap.data ?? const <TeamMember>[])
                .where((m) => m.teamId == team.id)
                .toList()
              ..sort((a, b) => a.userName
                  .toLowerCase()
                  .compareTo(b.userName.toLowerCase()));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final existing = {for (final m in members) m.userId};
                      final user = await _pickUser(context, fs, existing);
                      if (user != null) await fs.addTeamMember(team, user);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add member'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text('No members yet.'))
                      : ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final m = members[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_outline),
                              title: Text(m.userName),
                              trailing: IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () => fs.removeTeamMember(m),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
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
