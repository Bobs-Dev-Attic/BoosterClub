import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/event_categories.dart';
import '../../models/content_models.dart';
import '../../services/firestore_service.dart';

/// The event fields a CSV column can map to. `title` is required.
const List<String> kImportFields = [
  'title',
  'category',
  'startDate',
  'startTime',
  'endDate',
  'endTime',
  'location',
  'description',
];

const Map<String, String> _fieldLabels = {
  'title': 'Title *',
  'category': 'Category',
  'startDate': 'Start date',
  'startTime': 'Start time',
  'endDate': 'End date',
  'endTime': 'End time',
  'location': 'Location',
  'description': 'Description',
};

class _LogEntry {
  final int row;
  final String title;
  final String outcome; // imported / updated / replaced / skipped / error
  final String? note;
  const _LogEntry(this.row, this.title, this.outcome, [this.note]);
}

/// CSV import wizard for events: pick → map columns → choose duplicate handling
/// → import with a per-row log and summary report.
class EventImportDialog extends StatefulWidget {
  final FirestoreService fs;
  const EventImportDialog({super.key, required this.fs});

  @override
  State<EventImportDialog> createState() => _EventImportDialogState();
}

class _EventImportDialogState extends State<EventImportDialog> {
  int _step = 0; // 0 pick/map, 1 duplicates, 2 report
  List<String> _headers = [];
  List<List<String>> _rows = [];
  final Map<String, int?> _mapping = {for (final f in kImportFields) f: null};
  String _strategy = 'update'; // update / skip / allow / replace
  bool _busy = false;
  String? _error;

  // Report
  final List<_LogEntry> _log = [];
  int _imported = 0, _updated = 0, _replaced = 0, _skipped = 0, _errors = 0;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
        return;
      }
      final text = utf8.decode(res.files.first.bytes!, allowMalformed: true);
      final table = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
          .convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
      if (table.isEmpty) {
        setState(() => _error = 'The file appears to be empty.');
        return;
      }
      final headers = table.first.map((e) => e.toString().trim()).toList();
      final rows = table
          .skip(1)
          .where((r) => r.any((c) => c.toString().trim().isNotEmpty))
          .map((r) => List<String>.generate(
              headers.length,
              (i) => i < r.length ? r[i].toString().trim() : ''))
          .toList();
      setState(() {
        _headers = headers;
        _rows = rows;
        _autoMap();
      });
    } catch (e) {
      setState(() => _error = 'Could not read the file: $e');
    }
  }

  void _autoMap() {
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final field in kImportFields) {
      final target = norm(field);
      for (var i = 0; i < _headers.length; i++) {
        final h = norm(_headers[i]);
        if (h == target ||
            (field == 'title' && (h.contains('title') || h.contains('name') || h.contains('event'))) ||
            (field == 'startDate' && h.contains('start') && h.contains('date')) ||
            (field == 'startTime' && h.contains('start') && h.contains('time')) ||
            (field == 'endDate' && h.contains('end') && h.contains('date')) ||
            (field == 'endTime' && h.contains('end') && h.contains('time')) ||
            (field == 'category' && (h.contains('categor') || h.contains('type'))) ||
            (field == 'location' && (h.contains('location') || h.contains('place') || h.contains('venue'))) ||
            (field == 'description' && (h.contains('desc') || h.contains('detail')))) {
          _mapping[field] = i;
          break;
        }
      }
    }
  }

  static final _dateFormats = [
    'M/d/yyyy', 'M/d/yy', 'yyyy-MM-dd', 'MMMM d, yyyy', 'MMM d, yyyy', 'd-MMM-yyyy',
  ];
  static final _timeFormats = ['h:mm a', 'h:mma', 'H:mm', 'HH:mm', 'h a'];

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    for (final f in _dateFormats) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {}
    }
    return DateTime.tryParse(s);
  }

  Duration? _parseTime(String s) {
    if (s.isEmpty) return null;
    for (final f in _timeFormats) {
      try {
        final t = DateFormat(f).parseStrict(s);
        return Duration(hours: t.hour, minutes: t.minute);
      } catch (_) {}
    }
    return null;
  }

  String _cell(List<String> row, String field) {
    final i = _mapping[field];
    return (i != null && i < row.length) ? row[i] : '';
  }

  DateTime? _dateTimeFor(List<String> row, String dateField, String timeField) {
    final d = _parseDate(_cell(row, dateField));
    if (d == null) return null;
    final t = _parseTime(_cell(row, timeField));
    return t == null ? d : DateTime(d.year, d.month, d.day).add(t);
  }

  String _dupKey(String title, DateTime? start) =>
      '${title.trim().toLowerCase()}|${start != null ? DateFormat('yyyy-MM-dd').format(start) : ''}';

  Future<void> _runImport() async {
    setState(() {
      _busy = true;
      _error = null;
      _log.clear();
      _imported = _updated = _replaced = _skipped = _errors = 0;
    });
    try {
      final existing = await widget.fs.events().first;
      final byKey = <String, SchoolEvent>{};
      for (final e in existing) {
        byKey[_dupKey(e.title, e.startsAt)] = e;
      }
      final seen = <String>{};

      for (var r = 0; r < _rows.length; r++) {
        final row = _rows[r];
        final rowNum = r + 2; // 1-based + header
        final title = _cell(row, 'title');
        if (title.isEmpty) {
          _errors++;
          _log.add(_LogEntry(rowNum, '(no title)', 'error', 'Missing title'));
          continue;
        }
        final catRaw = _cell(row, 'category');
        final category = kEventCategories
                .any((c) => c.key.toLowerCase() == catRaw.toLowerCase())
            ? kEventCategories
                .firstWhere((c) => c.key.toLowerCase() == catRaw.toLowerCase())
                .key
            : 'General';
        final start = _dateTimeFor(row, 'startDate', 'startTime');
        final end = _dateTimeFor(row, 'endDate', 'endTime');
        final candidate = SchoolEvent(
          id: 'new',
          title: title,
          description: _cell(row, 'description'),
          location: _cell(row, 'location'),
          startsAt: start,
          endsAt: end,
          category: category,
        );
        final key = _dupKey(title, start);
        final match = byKey[key];
        final isDup = match != null || seen.contains(key);

        try {
          if (!isDup) {
            await widget.fs.upsert('events', candidate);
            seen.add(key);
            _imported++;
            _log.add(_LogEntry(rowNum, title, 'imported'));
          } else if (_strategy == 'skip') {
            _skipped++;
            _log.add(_LogEntry(rowNum, title, 'skipped', 'Duplicate'));
          } else if (_strategy == 'allow') {
            await widget.fs.upsert('events', candidate);
            _imported++;
            _log.add(_LogEntry(rowNum, title, 'imported', 'Duplicate allowed'));
          } else if (match == null) {
            // Duplicate only within this file — no existing id to update.
            await widget.fs.upsert('events', candidate);
            _imported++;
            _log.add(_LogEntry(rowNum, title, 'imported', 'Duplicate within file'));
          } else if (_strategy == 'replace') {
            await widget.fs.upsert(
                'events',
                SchoolEvent(
                  id: match.id,
                  title: candidate.title,
                  description: candidate.description,
                  location: candidate.location,
                  startsAt: candidate.startsAt,
                  endsAt: candidate.endsAt,
                  category: candidate.category,
                ));
            _replaced++;
            _log.add(_LogEntry(rowNum, title, 'replaced'));
          } else {
            // update: keep existing values where the CSV cell is blank
            await widget.fs.upsert(
                'events',
                SchoolEvent(
                  id: match.id,
                  title: candidate.title,
                  description: candidate.description.isNotEmpty
                      ? candidate.description
                      : match.description,
                  location: candidate.location.isNotEmpty
                      ? candidate.location
                      : match.location,
                  startsAt: candidate.startsAt ?? match.startsAt,
                  endsAt: candidate.endsAt ?? match.endsAt,
                  category: candidate.category,
                ));
            _updated++;
            _log.add(_LogEntry(rowNum, title, 'updated'));
          }
        } catch (e) {
          _errors++;
          _log.add(_LogEntry(rowNum, title, 'error', '$e'));
        }
      }
      setState(() {
        _busy = false;
        _step = 2;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(['Import Events — Map Columns', 'Handle Duplicates',
              'Import Report'][_step]),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (_step) {
              0 => _mapStep(),
              1 => _dupStep(),
              _ => _reportStep(),
            },
          ),
        ),
      ),
    );
  }

  // ---- Step 0: pick + map ----
  Widget _mapStep() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Upload a .csv with a header row, then map each event field to a column.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file),
          label: Text(_headers.isEmpty
              ? 'Choose CSV file'
              : '${_rows.length} rows loaded — choose another'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_headers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Column mapping',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final field in kImportFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                      width: 120,
                      child: Text(_fieldLabels[field] ?? field)),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _mapping[field],
                      isExpanded: true,
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('— none —')),
                        for (var i = 0; i < _headers.length; i++)
                          DropdownMenuItem<int?>(
                              value: i, child: Text(_headers[i])),
                      ],
                      onChanged: (v) => setState(() => _mapping[field] = v),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('Preview (first 3 rows)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          _previewTable(),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _mapping['title'] == null
                  ? null
                  : () => setState(() => _step = 1),
              child: const Text('Next: duplicates'),
            ),
          ),
          if (_mapping['title'] == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Map the required Title field to continue.',
                  style: TextStyle(color: Colors.orange)),
            ),
        ],
      ],
    );
  }

  Widget _previewTable() {
    final preview = _rows.take(3).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [for (final h in _headers) DataColumn(label: Text(h))],
        rows: [
          for (final row in preview)
            DataRow(cells: [
              for (var i = 0; i < _headers.length; i++)
                DataCell(Text(i < row.length ? row[i] : '')),
            ]),
        ],
      ),
    );
  }

  // ---- Step 1: duplicates ----
  Widget _dupStep() {
    const options = [
      ('update', 'Update', 'Update the existing event with the new data (keeps blanks).'),
      ('replace', 'Replace', 'Overwrite the existing event entirely with the CSV values.'),
      ('skip', 'Skip', 'Leave the existing event untouched; ignore the CSV row.'),
      ('allow', 'Allow', 'Import anyway as a separate, additional event.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'A row is a duplicate when its title and start date match an existing event. Choose how to handle duplicates:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _strategy,
          onChanged: (v) => setState(() => _strategy = v ?? _strategy),
          child: Column(
            children: [
              for (final o in options)
                RadioListTile<String>(
                  value: o.$1,
                  title: Text(o.$2),
                  subtitle: Text(o.$3),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
                onPressed: _busy ? null : () => setState(() => _step = 0),
                child: const Text('Back')),
            FilledButton.icon(
              onPressed: _busy ? null : _runImport,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_done),
              label: Text(_busy ? 'Importing…' : 'Import ${_rows.length} rows'),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Step 2: report ----
  Widget _reportStep() {
    Color colorFor(String o) => switch (o) {
          'imported' => Colors.green,
          'updated' => Colors.blue,
          'replaced' => Colors.orange,
          'skipped' => Colors.grey,
          _ => Colors.red,
        };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat('New', _imported, Colors.green),
              _stat('Updated', _updated, Colors.blue),
              _stat('Replaced', _replaced, Colors.orange),
              _stat('Skipped', _skipped, Colors.grey),
              _stat('Errors', _errors, Colors.red),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _log.length,
            itemBuilder: (context, i) {
              final e = _log[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: colorFor(e.outcome).withValues(alpha: 0.15),
                  child: Text('${e.row}',
                      style: TextStyle(
                          fontSize: 10, color: colorFor(e.outcome))),
                ),
                title: Text(e.title),
                subtitle: e.note != null ? Text(e.note!) : null,
                trailing: Text(e.outcome,
                    style: TextStyle(
                        color: colorFor(e.outcome),
                        fontWeight: FontWeight.w600)),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, int value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      );
}
