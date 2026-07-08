import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/content_models.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

/// Public renderer for a legal/policy document (Terms of Use, Privacy Policy).
/// The body uses a light markup: `# `/`## ` headings, `- ` bullets, and inline
/// `**bold**` / `_italic_`.
class LegalScreen extends StatelessWidget {
  final String docId; // 'terms' | 'privacy'
  final String fallbackTitle;
  const LegalScreen(
      {super.key, required this.docId, required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return PageBody(
      maxWidth: 820,
      child: StreamBuilder<List<LegalDocument>>(
        stream: fs.legalDocuments(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
                icon: Icons.error_outline,
                message: 'Something went wrong.\n${snap.error}');
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final match = snap.data!.where((d) => d.id == docId);
          if (match.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: fallbackTitle, icon: Icons.gavel),
                const EmptyState(
                  icon: Icons.description_outlined,
                  message: 'This document has not been published yet.',
                ),
              ],
            );
          }
          final doc = match.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: doc.title.isNotEmpty ? doc.title : fallbackTitle,
                icon: Icons.gavel,
                subtitle: doc.updatedAt != null
                    ? 'Last updated ${DateFormat('MMMM d, y').format(doc.updatedAt!)}'
                    : null,
              ),
              SelectionArea(child: _LegalBody(doc.body)),
            ],
          );
        },
      ),
    );
  }
}

/// Renders the light-markup body into styled blocks.
class _LegalBody extends StatelessWidget {
  final String body;
  const _LegalBody(this.body);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];

    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 10));
      } else if (line.startsWith('# ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(line.substring(2),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ));
      } else if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Text(line.substring(3),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ));
      } else if (line.startsWith('- ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(
                child: Text.rich(
                    TextSpan(children: _inline(line.substring(2), theme))),
              ),
            ],
          ),
        ));
      } else {
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text.rich(TextSpan(children: _inline(line, theme))),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  /// Parses inline `**bold**` and `_italic_` markers into styled spans.
  List<TextSpan> _inline(String text, ThemeData theme) {
    final base = theme.textTheme.bodyLarge;
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|_(.+?)_');
    var i = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > i) {
        spans.add(TextSpan(text: text.substring(i, m.start), style: base));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: base?.copyWith(fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(
            text: m.group(2),
            style: base?.copyWith(fontStyle: FontStyle.italic)));
      }
      i = m.end;
    }
    if (i < text.length) {
      spans.add(TextSpan(text: text.substring(i), style: base));
    }
    return spans;
  }
}
