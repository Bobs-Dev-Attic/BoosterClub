import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class SponsorshipsScreen extends StatelessWidget {
  const SponsorshipsScreen({super.key});

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return const Color(0xFF6D7B8D);
      case 'gold':
        return const Color(0xFFF6B12B);
      case 'silver':
        return const Color(0xFF9AA5B1);
      case 'bronze':
        return const Color(0xFFB08D57);
      default:
        return const Color(0xFF1E4A8C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Corporate Sponsorships',
            icon: Icons.handshake,
            subtitle:
                'Partner with us to support students and get your business seen.',
          ),
          StreamListView<Sponsorship>(
            stream: fs.sponsorships(),
            emptyIcon: Icons.handshake_outlined,
            emptyMessage: 'Sponsorship tiers coming soon.',
            builder: (context, items) => ResponsiveGrid(
              minTileWidth: 300,
              children: [
                for (final s in items) _SponsorCard(s, _tierColor(s.tier))
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Interested in sponsoring?',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Contact our sponsorship team at sponsors@boosterclub.org '
                          'or create a sponsor account to get started.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorCard extends StatelessWidget {
  final Sponsorship s;
  final Color accent;
  const _SponsorCard(this.s, this.accent);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 8,
            color: accent,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (s.tier.isNotEmpty) Pill(s.tier, color: accent),
                    const Spacer(),
                    Text('\$${s.amount.toStringAsFixed(0)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(s.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                const SizedBox(height: 12),
                for (final b in s.benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            size: 16, color: accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
