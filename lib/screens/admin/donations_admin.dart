import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Read-only view of the donations ledger recorded in Firestore. Donations are
/// written as pending by the app and confirmed by the PayPal Cloud Functions,
/// so this reflects real payment state — it is never edited by hand here.
class DonationsAdmin extends StatelessWidget {
  final FirestoreService fs;
  const DonationsAdmin({super.key, required this.fs});

  static final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  Color _statusColor(DonationStatus s) {
    switch (s) {
      case DonationStatus.completed:
        return Colors.green;
      case DonationStatus.pending:
        return Colors.orange;
      case DonationStatus.failed:
        return Colors.red;
      case DonationStatus.refunded:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Donations',
            subtitle:
                'Every donation recorded in Firestore. Status is set by PayPal '
                'confirmation, not edited here.',
          ),
          StreamListView<Donation>(
            stream: fs.donations(),
            emptyIcon: Icons.favorite_border,
            emptyMessage: 'No donations recorded yet.',
            builder: (context, items) {
              final completed =
                  items.where((d) => d.status == DonationStatus.completed);
              final total =
                  completed.fold<double>(0, (sum, d) => sum + d.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _stat(context, 'Raised', _money.format(total)),
                          _stat(context, 'Completed',
                              '${completed.length}'),
                          _stat(context, 'All records', '${items.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final d in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(d.status).withValues(alpha: 0.15),
                          child: Icon(Icons.favorite,
                              color: _statusColor(d.status), size: 18),
                        ),
                        title: Text(
                            '${_money.format(d.amount)} · ${d.designation}'),
                        subtitle: Text(
                          '${d.donorName.isEmpty ? 'Anonymous' : d.donorName}'
                          ' · ${d.donorEmail}'
                          '${d.createdAt != null ? '\n${DateFormat('MMM d, y · h:mm a').format(d.createdAt!)}' : ''}',
                        ),
                        isThreeLine: d.createdAt != null,
                        trailing: Pill(d.status.label,
                            color: _statusColor(d.status)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
