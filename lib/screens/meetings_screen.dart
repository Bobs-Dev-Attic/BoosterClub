import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_models.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();
    final canPost = auth.user?.can('manage_meetings') ?? false;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Meetings & Minutes',
            icon: Icons.groups,
            subtitle: 'Upcoming meetings and archived minutes.',
            action: canPost
                ? FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _PostMinutesDialog(fs: fs),
                    ),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Post minutes'),
                  )
                : null,
          ),
          StreamListView<Meeting>(
            stream: fs.meetings(),
            emptyIcon: Icons.groups_outlined,
            emptyMessage: 'No meetings posted yet.',
            builder: (context, items) => Column(
              children: [for (final m in items) _MeetingTile(m)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets a Contributor (or content manager) upload a meeting-minutes PDF, which
/// is stored and added to the Meetings list.
class _PostMinutesDialog extends StatefulWidget {
  final FirestoreService fs;
  const _PostMinutesDialog({required this.fs});

  @override
  State<_PostMinutesDialog> createState() => _PostMinutesDialogState();
}

class _PostMinutesDialogState extends State<_PostMinutesDialog> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime(2026, 7, 6);
  PlatformFile? _file;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _file = res.files.first);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    if (_file?.bytes == null) {
      setState(() => _error = 'Choose a PDF file.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stamp = _date.millisecondsSinceEpoch;
      final url = await widget.fs
          .uploadMinutesPdf(_file!.bytes!, _file!.name, stamp);
      await widget.fs.upsert(
        'meetings',
        Meeting(
          id: 'new',
          title: _title.text.trim(),
          description: _notes.text.trim().isEmpty
              ? 'Meeting minutes posted.'
              : _notes.text.trim(),
          meetingDate: _date,
          minutesUrl: url,
        ),
      );
      navigator.pop();
      messenger.showSnackBar(
          const SnackBar(content: Text('Minutes posted.')));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post Meeting Minutes'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'Title (e.g. Board Meeting — March)'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Meeting date',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(_file?.name ?? 'Choose PDF'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Upload & post'),
        ),
      ],
    );
  }
}

class _MeetingTile extends StatelessWidget {
  final Meeting m;
  const _MeetingTile(this.m);

  @override
  Widget build(BuildContext context) {
    final hasMinutes = m.minutesUrl != null && m.minutesUrl!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(m.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (hasMinutes)
                  const Pill('Minutes', icon: Icons.description, color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                if (m.meetingDate != null)
                  _meta(context, Icons.calendar_today,
                      DateFormat('EEE, MMM d, yyyy').format(m.meetingDate!)),
                if (m.location.isNotEmpty)
                  _meta(context, Icons.place, m.location),
              ],
            ),
            const SizedBox(height: 8),
            Text(m.description,
                style: Theme.of(context).textTheme.bodyMedium),
            if (hasMinutes) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _open(m.minutesUrl!),
                icon: const Icon(Icons.download),
                label: const Text('View minutes'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ],
      );
}
