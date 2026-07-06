import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class VolunteeringScreen extends StatelessWidget {
  const VolunteeringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Volunteering',
            icon: Icons.volunteer_activism,
            subtitle: 'Lend a hand — every shift makes a difference.',
          ),
          StreamListView<VolunteerOpportunity>(
            stream: fs.volunteering(),
            emptyIcon: Icons.handshake_outlined,
            emptyMessage: 'No open opportunities right now.',
            builder: (context, items) => ResponsiveGrid(
              children: [for (final o in items) _OppCard(o)],
            ),
          ),
        ],
      ),
    );
  }
}

class _OppCard extends StatelessWidget {
  final VolunteerOpportunity opp;
  const _OppCard(this.opp);

  @override
  Widget build(BuildContext context) {
    final full = opp.spotsRemaining == 0 && opp.spotsNeeded > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (opp.date != null)
                  Pill(DateFormat('MMM d').format(opp.date!),
                      icon: Icons.calendar_today),
                const Spacer(),
                Pill(
                  full ? 'Full' : '${opp.spotsRemaining} spots left',
                  color: full ? Colors.grey : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(opp.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                opp.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: full ? null : () => _signUp(context),
                child: Text(full ? 'Full' : 'Sign up'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _signUp(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please sign in to volunteer.')));
      return;
    }
    messenger.showSnackBar(SnackBar(
        content: Text('Thanks for signing up for "${opp.title}"!')));
  }
}
