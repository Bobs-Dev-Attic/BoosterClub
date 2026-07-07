import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "This Day in Wildcat History" — surfaces today's history fact (or a rotating
/// one). Contributors get a manage button to add/edit/delete facts.
class HistorySection extends StatelessWidget {
  const HistorySection({super.key});

  HistoryFact? _pick(List<HistoryFact> facts) {
    if (facts.isEmpty) return null;
    final now = DateTime.now();
    for (final f in facts) {
      if (f.month == now.month && f.day == now.day) return f;
    }
    // No exact match — rotate deterministically by day-of-year.
    final doy = now.difference(DateTime(now.year, 1, 1)).inDays;
    return facts[doy % facts.length];
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final canManage = context.watch<AuthProvider>().user?.can('manage_history') ?? false;

    return StreamBuilder<List<HistoryFact>>(
      stream: fs.historyFacts(),
      builder: (context, snap) {
        final facts = snap.data ?? const <HistoryFact>[];
        final fact = _pick(facts);
        if (fact == null && !canManage) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.green.withValues(alpha: 0.4)),
            color: AppTheme.green.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories, color: AppTheme.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('This Day in Wildcat History',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.green)),
                  ),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _ManageHistoryDialog(fs: fs),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Manage'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (fact == null)
                Text('No history facts yet — add one with Manage.',
                    style: Theme.of(context).textTheme.bodyMedium)
              else ...[
                Row(
                  children: [
                    Pill(
                      fact.year != null
                          ? '${DateFormat('MMM d').format(DateTime(2000, fact.month, fact.day))}, ${fact.year}'
                          : DateFormat('MMM d')
                              .format(DateTime(2000, fact.month, fact.day)),
                      icon: Icons.calendar_today,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(fact.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(fact.fact,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ManageHistoryDialog extends StatelessWidget {
  final FirestoreService fs;
  const _ManageHistoryDialog({required this.fs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage History Facts'),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Add fact'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<HistoryFact>>(
                stream: fs.historyFacts(),
                builder: (context, snap) {
                  final facts = snap.data ?? const <HistoryFact>[];
                  if (facts.isEmpty) {
                    return const Center(child: Text('No facts yet.'));
                  }
                  return ListView(
                    children: [
                      for (final f in facts)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(f.title),
                            subtitle: Text(
                                '${DateFormat('MMM d').format(DateTime(2000, f.month, f.day))}${f.year != null ? ', ${f.year}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(context, f),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      fs.delete('history_facts', f.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
            child: const Text('Done')),
      ],
    );
  }

  void _edit(BuildContext context, HistoryFact? f) {
    final title = TextEditingController(text: f?.title);
    final fact = TextEditingController(text: f?.fact);
    final year = TextEditingController(text: f?.year?.toString() ?? '');
    DateTime date = DateTime(2000, f?.month ?? DateTime.now().month,
        f?.day ?? DateTime.now().day);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(f == null ? 'New Fact' : 'Edit Fact'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setLocal) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                              DateTime.now().year, date.month, date.day),
                          firstDate: DateTime(DateTime.now().year, 1, 1),
                          lastDate: DateTime(DateTime.now().year, 12, 31),
                          helpText: 'Pick the month & day',
                        );
                        if (picked != null) {
                          setLocal(() =>
                              date = DateTime(2000, picked.month, picked.day));
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Month & day',
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child:
                            Text(DateFormat('MMMM d').format(date)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Year (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: fact,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Fact'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await fs.upsert(
                'history_facts',
                HistoryFact(
                  id: f?.id ?? 'new',
                  title: title.text.trim(),
                  fact: fact.text.trim(),
                  month: date.month,
                  day: date.day,
                  year: int.tryParse(year.text.trim()),
                ),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
