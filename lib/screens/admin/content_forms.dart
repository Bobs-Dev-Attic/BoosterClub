import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/content_models.dart';

/// A reusable modal form scaffold. [build] receives a submit callback that,
/// when called with a value, closes the dialog and returns it.
Future<T?> _formDialog<T>(
  BuildContext context, {
  required String title,
  required Widget Function(GlobalKey<FormState>, void Function(T)) build,
}) {
  final formKey = GlobalKey<FormState>();
  return showDialog<T>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: build(formKey, (value) => Navigator.pop(context, value)),
          ),
        ),
      );
    },
  );
}

class _DateField extends StatefulWidget {
  final String label;
  final DateTime? initial;
  final ValueChanged<DateTime?> onChanged;
  const _DateField(
      {required this.label, this.initial, required this.onChanged});

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  DateTime? _value;
  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _value ?? DateTime(2026, 7, 6),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) {
          setState(() => _value = picked);
          widget.onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_value != null
            ? DateFormat('EEE, MMM d, yyyy').format(_value!)
            : 'Select a date'),
      ),
    );
  }
}

/// Time-of-day options in 30-minute steps, 12-hour format with AM/PM.
class _TimeSlot {
  final int minutes; // minutes since midnight
  final String label;
  const _TimeSlot(this.minutes, this.label);
}

List<_TimeSlot> _buildTimeSlots() {
  final slots = <_TimeSlot>[];
  for (var m = 0; m < 24 * 60; m += 30) {
    final h = m ~/ 60;
    final min = m % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final ampm = h < 12 ? 'AM' : 'PM';
    slots.add(_TimeSlot(m, '$h12:${min == 0 ? '00' : '30'} $ampm'));
  }
  return slots;
}

final List<_TimeSlot> _kTimeSlots = _buildTimeSlots();

int _roundToSlot(DateTime d) {
  final total = d.hour * 60 + d.minute;
  return ((total / 30).round() * 30) % (24 * 60);
}

/// A combined date + 30-minute time-of-day picker. Emits a single [DateTime]
/// (or null when no date is chosen).
class _DateTimePicker extends StatefulWidget {
  final String label;
  final DateTime? initial;
  final ValueChanged<DateTime?> onChanged;
  const _DateTimePicker(
      {required this.label, this.initial, required this.onChanged});

  @override
  State<_DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<_DateTimePicker> {
  DateTime? _date; // date-only
  int _minutes = 18 * 60; // default 6:00 PM

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _date = DateTime(i.year, i.month, i.day);
      _minutes = _roundToSlot(i);
    }
  }

  void _emit() {
    if (_date == null) {
      widget.onChanged(null);
    } else {
      widget.onChanged(DateTime(
          _date!.year, _date!.month, _date!.day, _minutes ~/ 60, _minutes % 60));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime(2026, 7, 6),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() => _date = picked);
                _emit();
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                _date != null
                    ? DateFormat('EEE, MMM d, yyyy').format(_date!)
                    : 'Select a date',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            initialValue: _minutes,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Time',
              prefixIcon: Icon(Icons.schedule, size: 18),
            ),
            items: [
              for (final s in _kTimeSlots)
                DropdownMenuItem(value: s.minutes, child: Text(s.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _minutes = v);
              _emit();
            },
          ),
        ),
      ],
    );
  }
}

InputDecoration _dec(String label) => InputDecoration(labelText: label);

Widget _actions(GlobalKey<FormState> key, VoidCallback onSave) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() ?? true) onSave();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

// ---- Event ---------------------------------------------------------------
Future<SchoolEvent?> editEvent(BuildContext context, SchoolEvent? e) {
  final title = TextEditingController(text: e?.title);
  final desc = TextEditingController(text: e?.description);
  final loc = TextEditingController(text: e?.location);
  DateTime? start = e?.startsAt;
  DateTime? end = e?.endsAt;
  return _formDialog<SchoolEvent>(
    context,
    title: e == null ? 'New Event' : 'Edit Event',
    build: (key, submit) => StatefulBuilder(
      builder: (context, setLocal) {
        String? error;
        void trySubmit() {
          if (!(key.currentState?.validate() ?? true)) return;
          if (start != null && end != null && end!.isBefore(start!)) {
            setLocal(() => error = 'End must be after the start.');
            return;
          }
          submit(SchoolEvent(
            id: e?.id ?? 'new',
            title: title.text.trim(),
            description: desc.text.trim(),
            location: loc.text.trim(),
            startsAt: start,
            endsAt: end,
          ));
        }

        return Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: title,
                  decoration: _dec('Title'),
                  validator: _required),
              const SizedBox(height: 12),
              _DateTimePicker(
                  label: 'Start Date',
                  initial: start,
                  onChanged: (v) => start = v),
              const SizedBox(height: 12),
              _DateTimePicker(
                  label: 'End Date', initial: end, onChanged: (v) => end = v),
              const SizedBox(height: 12),
              TextFormField(controller: loc, decoration: _dec('Location')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: desc,
                  decoration: _dec('Description'),
                  maxLines: 3,
                  validator: _required),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                        onPressed: trySubmit, child: const Text('Save')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ---- Volunteer -----------------------------------------------------------
Future<VolunteerOpportunity?> editVolunteer(
    BuildContext context, VolunteerOpportunity? o) {
  final title = TextEditingController(text: o?.title);
  final desc = TextEditingController(text: o?.description);
  final needed = TextEditingController(text: o?.spotsNeeded.toString());
  final filled = TextEditingController(text: o?.spotsFilled.toString());
  DateTime? date = o?.date;
  return _formDialog<VolunteerOpportunity>(
    context,
    title: o == null ? 'New Opportunity' : 'Edit Opportunity',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: title,
              decoration: _dec('Title'),
              validator: _required),
          const SizedBox(height: 12),
          _DateField(
              label: 'Date', initial: date, onChanged: (v) => date = v),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: needed,
                    decoration: _dec('Spots needed'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                    controller: filled,
                    decoration: _dec('Spots filled'),
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: desc,
              decoration: _dec('Description'),
              maxLines: 3,
              validator: _required),
          _actions(
            key,
            () => submit(VolunteerOpportunity(
              id: o?.id ?? 'new',
              title: title.text.trim(),
              description: desc.text.trim(),
              date: date,
              spotsNeeded: int.tryParse(needed.text) ?? 0,
              spotsFilled: int.tryParse(filled.text) ?? 0,
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- Sponsorship ---------------------------------------------------------
Future<Sponsorship?> editSponsorship(BuildContext context, Sponsorship? s) {
  final title = TextEditingController(text: s?.title);
  final desc = TextEditingController(text: s?.description);
  final amount = TextEditingController(text: s?.amount.toStringAsFixed(0));
  final tier = TextEditingController(text: s?.tier);
  final benefits =
      TextEditingController(text: s?.benefits.join('\n') ?? '');
  return _formDialog<Sponsorship>(
    context,
    title: s == null ? 'New Sponsorship' : 'Edit Sponsorship',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: title,
              decoration: _dec('Title'),
              validator: _required),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: TextFormField(
                      controller: tier, decoration: _dec('Tier'))),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                    controller: amount,
                    decoration: _dec('Amount (\$)'),
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: desc,
              decoration: _dec('Description'),
              maxLines: 2,
              validator: _required),
          const SizedBox(height: 12),
          TextFormField(
              controller: benefits,
              decoration: _dec('Benefits (one per line)'),
              maxLines: 4),
          _actions(
            key,
            () => submit(Sponsorship(
              id: s?.id ?? 'new',
              title: title.text.trim(),
              description: desc.text.trim(),
              amount: double.tryParse(amount.text) ?? 0,
              tier: tier.text.trim(),
              benefits: benefits.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- Funding request -----------------------------------------------------
Future<FundingRequest?> editFunding(
    BuildContext context, FundingRequest? r) {
  final title = TextEditingController(text: r?.title);
  final desc = TextEditingController(text: r?.description);
  final amount =
      TextEditingController(text: r?.amountRequested.toStringAsFixed(0));
  final by = TextEditingController(text: r?.requestedBy);
  String status = r?.status ?? 'pending';
  const statuses = ['pending', 'approved', 'declined', 'funded'];
  return _formDialog<FundingRequest>(
    context,
    title: r == null ? 'New Funding Request' : 'Edit Funding Request',
    build: (key, submit) => StatefulBuilder(
      builder: (context, setLocal) => Form(
        key: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: title,
                decoration: _dec('Title'),
                validator: _required),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: by, decoration: _dec('Requested by'))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                      controller: amount,
                      decoration: _dec('Amount (\$)'),
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: _dec('Status'),
              items: [
                for (final s in statuses)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setLocal(() => status = v ?? status),
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: desc,
                decoration: _dec('Description'),
                maxLines: 3,
                validator: _required),
            _actions(
              key,
              () => submit(FundingRequest(
                id: r?.id ?? 'new',
                title: title.text.trim(),
                description: desc.text.trim(),
                amountRequested: double.tryParse(amount.text) ?? 0,
                requestedBy: by.text.trim(),
                status: status,
                submittedAt: r?.submittedAt ?? DateTime(2026, 7, 6),
              )),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---- Fundraiser ----------------------------------------------------------
Future<FundraisingEvent?> editFundraiser(
    BuildContext context, FundraisingEvent? f) {
  final title = TextEditingController(text: f?.title);
  final desc = TextEditingController(text: f?.description);
  final goal = TextEditingController(text: f?.goalAmount.toStringAsFixed(0));
  final raised =
      TextEditingController(text: f?.raisedAmount.toStringAsFixed(0));
  DateTime? ends = f?.endsAt;
  return _formDialog<FundraisingEvent>(
    context,
    title: f == null ? 'New Fundraiser' : 'Edit Fundraiser',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: title,
              decoration: _dec('Title'),
              validator: _required),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                    controller: goal,
                    decoration: _dec('Goal (\$)'),
                    keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                    controller: raised,
                    decoration: _dec('Raised (\$)'),
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DateField(
              label: 'Ends', initial: ends, onChanged: (v) => ends = v),
          const SizedBox(height: 12),
          TextFormField(
              controller: desc,
              decoration: _dec('Description'),
              maxLines: 3,
              validator: _required),
          _actions(
            key,
            () => submit(FundraisingEvent(
              id: f?.id ?? 'new',
              title: title.text.trim(),
              description: desc.text.trim(),
              goalAmount: double.tryParse(goal.text) ?? 0,
              raisedAmount: double.tryParse(raised.text) ?? 0,
              endsAt: ends,
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- Meeting -------------------------------------------------------------
Future<Meeting?> editMeeting(BuildContext context, Meeting? m) {
  final title = TextEditingController(text: m?.title);
  final desc = TextEditingController(text: m?.description);
  final loc = TextEditingController(text: m?.location);
  final minutes = TextEditingController(text: m?.minutesUrl ?? '');
  DateTime? date = m?.meetingDate;
  return _formDialog<Meeting>(
    context,
    title: m == null ? 'New Meeting' : 'Edit Meeting',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: title,
              decoration: _dec('Title'),
              validator: _required),
          const SizedBox(height: 12),
          _DateField(
              label: 'Meeting date',
              initial: date,
              onChanged: (v) => date = v),
          const SizedBox(height: 12),
          TextFormField(controller: loc, decoration: _dec('Location')),
          const SizedBox(height: 12),
          TextFormField(
              controller: minutes,
              decoration: _dec('Minutes URL (optional)')),
          const SizedBox(height: 12),
          TextFormField(
              controller: desc,
              decoration: _dec('Description'),
              maxLines: 3,
              validator: _required),
          _actions(
            key,
            () => submit(Meeting(
              id: m?.id ?? 'new',
              title: title.text.trim(),
              description: desc.text.trim(),
              location: loc.text.trim(),
              minutesUrl: minutes.text.trim().isEmpty
                  ? null
                  : minutes.text.trim(),
              meetingDate: date,
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- FAQ -----------------------------------------------------------------
Future<FaqItem?> editFaq(BuildContext context, FaqItem? q) {
  final question = TextEditingController(text: q?.question);
  final answer = TextEditingController(text: q?.answer);
  final order = TextEditingController(text: (q?.order ?? 0).toString());
  return _formDialog<FaqItem>(
    context,
    title: q == null ? 'New FAQ' : 'Edit FAQ',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: question,
              decoration: _dec('Question'),
              validator: _required),
          const SizedBox(height: 12),
          TextFormField(
              controller: answer,
              decoration: _dec('Answer'),
              maxLines: 4,
              validator: _required),
          const SizedBox(height: 12),
          TextFormField(
              controller: order,
              decoration: _dec('Display order'),
              keyboardType: TextInputType.number),
          _actions(
            key,
            () => submit(FaqItem(
              id: q?.id ?? 'new',
              question: question.text.trim(),
              answer: answer.text.trim(),
              order: int.tryParse(order.text) ?? 0,
            )),
          ),
        ],
      ),
    ),
  );
}
