import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class FundraisersScreen extends StatelessWidget {
  const FundraisersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Fundraising Events',
            icon: Icons.savings,
            subtitle: 'Help us reach our goals for the season.',
          ),
          StreamListView<FundraisingEvent>(
            stream: fs.fundraisers(),
            emptyIcon: Icons.savings_outlined,
            emptyMessage: 'No active fundraisers right now.',
            builder: (context, items) => Column(
              children: [for (final f in items) _FundraiserCard(f)],
            ),
          ),
        ],
      ),
    );
  }
}

class _FundraiserCard extends StatelessWidget {
  final FundraisingEvent f;
  const _FundraiserCard(this.f);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(f.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (f.endsAt != null)
                  Pill('Ends ${DateFormat('MMM d').format(f.endsAt!)}',
                      icon: Icons.timer_outlined),
              ],
            ),
            const SizedBox(height: 8),
            Text(f.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: f.progress, minHeight: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${f.raisedAmount.toStringAsFixed(0)} raised',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                Text('Goal: \$${f.goalAmount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/donate'),
              icon: const Icon(Icons.favorite),
              label: const Text('Contribute'),
            ),
          ],
        ),
      ),
    );
  }
}
