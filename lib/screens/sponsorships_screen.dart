import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class SponsorshipsScreen extends StatelessWidget {
  const SponsorshipsScreen({super.key});

  static const _sponsorEmail = 'sponsorship@wjboosterclub.org';

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
        return const Color(0xFF1E7A3D); // Wildcat green for the corporate banner
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
            title: 'Corporate Sponsorship',
            icon: Icons.handshake,
            subtitle:
                'Support WJ Boosters and advertise your business to thousands '
                'of fans.',
          ),

          // Value proposition banner.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stadium,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Support WJ Boosters and Advertise Your Business',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Prominently featured in the WJ stadium for one year, your '
                    'banner will be visible to thousands of fans who attend a '
                    'multitude of WJ and community-wide sporting events. '
                    "Let's get started!",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // The sponsorship offering (driven by Firestore).
          StreamListView<Sponsorship>(
            stream: fs.sponsorships(),
            emptyIcon: Icons.handshake_outlined,
            emptyMessage: 'Sponsorship details coming soon.',
            builder: (context, items) => ResponsiveGrid(
              minTileWidth: 320,
              children: [
                for (final s in items) _SponsorCard(s, _tierColor(s.tier))
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Banner specifications / how it works.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Banner details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._details.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(d,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Contact / call to action.
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
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
                        Text('Questions? Ready to sponsor?',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Send an email to $_sponsorEmail and we’ll help '
                          'you get started.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _email(_sponsorEmail),
                    icon: const Icon(Icons.email),
                    label: const Text('Email us'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _details = [
    'The 3½ × 9 foot banner is printed on sturdy, weather-resistant material '
        '(actual size may vary slightly based on graphics).',
    'Graphics are provided by the sponsor. Additional fees apply if extra '
        'graphical assistance is needed.',
    'Displayed on the fence inside the WJ stadium where it can be easily seen '
        'by all fans.',
    'Sponsorship valid for one year.',
    'Once full payment has been received, we’ll contact you to confirm '
        'graphics specifications, timing and final approval.',
  ];

  static Future<void> _email(String address) async {
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: 'subject=WJ Booster Club Corporate Sponsorship',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                    Text(
                      '\$${s.amount.toStringAsFixed(0)}/yr',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
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
                        Icon(Icons.check_circle, size: 16, color: accent),
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
