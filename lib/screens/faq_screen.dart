import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Frequently Asked Questions',
            icon: Icons.help,
            subtitle: 'Answers to common questions about the Booster Club.',
          ),
          StreamListView<FaqItem>(
            stream: fs.faqs(),
            emptyIcon: Icons.help_outline,
            emptyMessage: 'No FAQs posted yet.',
            builder: (context, items) => Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ExpansionTile(
                      shape: const Border(),
                      title: Text(items[i].question,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedAlignment: Alignment.centerLeft,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].answer,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
