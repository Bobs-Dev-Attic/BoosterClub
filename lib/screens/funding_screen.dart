import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/content_models.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class FundingScreen extends StatelessWidget {
  const FundingScreen({super.key});

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
      case 'funded':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();
    final canSubmit = auth.role.index >= UserRole.member.index;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Funding Requests',
            icon: Icons.request_quote,
            subtitle: 'Teams and clubs can request Booster Club support.',
            action: canSubmit
                ? FilledButton.icon(
                    onPressed: () => _showForm(context, fs, auth.user!),
                    icon: const Icon(Icons.add),
                    label: const Text('Request'),
                  )
                : null,
          ),
          if (!canSubmit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sign in as a member to submit a funding request.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          StreamListView<FundingRequest>(
            stream: fs.fundingRequests(),
            emptyIcon: Icons.request_quote_outlined,
            emptyMessage: 'No funding requests yet.',
            builder: (context, items) => Column(
              children: [
                for (final r in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(r.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                              ),
                              Pill(r.status.toUpperCase(),
                                  color: _statusColor(r.status)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(r.description,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Pill('\$${r.amountRequested.toStringAsFixed(0)}',
                                  icon: Icons.attach_money),
                              const SizedBox(width: 8),
                              if (r.requestedBy.isNotEmpty)
                                Text('by ${r.requestedBy}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              const Spacer(),
                              if (r.submittedAt != null)
                                Text(
                                    DateFormat('MMM d, yyyy')
                                        .format(r.submittedAt!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                            ],
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

  void _showForm(BuildContext context, FirestoreService fs, AppUser user) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final amountC = TextEditingController();
    final byC = TextEditingController(text: user.organization ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Funding Request'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: byC,
                    decoration:
                        const InputDecoration(labelText: 'Team / Club'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Amount requested', prefixText: '\$ '),
                    validator: (v) =>
                        (double.tryParse(v ?? '') == null) ? 'Enter a number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descC,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await fs.submitFundingRequest(FundingRequest(
                id: 'new',
                title: titleC.text.trim(),
                description: descC.text.trim(),
                amountRequested: double.parse(amountC.text.trim()),
                requestedBy: byC.text.trim(),
                status: 'pending',
                submittedAt: DateTime.now(),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
