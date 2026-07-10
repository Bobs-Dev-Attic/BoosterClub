import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/event_categories.dart';
import '../../models/content_models.dart';
import '../../services/firestore_service.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/common.dart';

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

/// A combined date + 30-minute time-of-day picker. The time is optional: a
/// leading "blank" option leaves the time unspecified. This is a controlled
/// widget — [date] (date-only) and [minutes] (null = blank/no time) are owned
/// by the parent.
class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? date;
  final int? minutes;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<int?> onTimeChanged;
  const _DateTimePicker({
    required this.label,
    required this.date,
    required this.minutes,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

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
                initialDate: date ?? DateTime(2026, 7, 6),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                onDateChanged(
                    DateTime(picked.year, picked.month, picked.day));
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                date != null
                    ? DateFormat('EEE, MMM d, yyyy').format(date!)
                    : 'Select a date',
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int?>(
            initialValue: minutes,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Time',
              prefixIcon: Icon(Icons.schedule, size: 18),
            ),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('— blank —')),
              for (final s in _kTimeSlots)
                DropdownMenuItem<int?>(value: s.minutes, child: Text(s.label)),
            ],
            onChanged: onTimeChanged,
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

/// Validates an optional URL: blank is fine, otherwise it must parse as an
/// absolute http(s) URL.
String? _optionalUrl(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return 'Enter a full URL (https://…) or leave blank';
  }
  return null;
}

/// Parses a "latitude, longitude" string into a pair of doubles. Returns
/// `(null, null)` when the input is blank or malformed.
(double?, double?) _parseLatLng(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return (null, null);
  final parts = s.split(',');
  if (parts.length != 2) return (null, null);
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return (null, null);
  return (lat, lng);
}

/// Validates an optional "latitude, longitude" geolocation field.
String? _optionalLatLng(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  final (lat, lng) = _parseLatLng(s);
  if (lat == null ||
      lng == null ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180) {
    return 'Enter "latitude, longitude" (e.g. 39.03, -77.11) or leave blank';
  }
  return null;
}

/// Result of the address-lookup dialog: a composed display address, the raw
/// entered parts (saved on the event), and — when the geocoder matched — its
/// coordinates.
class _AddressLookupResult {
  final String address;
  final String street;
  final String city;
  final String state;
  final String zip;
  final double? latitude;
  final double? longitude;
  const _AddressLookupResult({
    required this.address,
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    this.latitude,
    this.longitude,
  });
}

/// Opens a dialog to enter a US address, then geocodes it via the U.S. Census
/// geocoder to determine latitude/longitude. The dialog is pre-filled from any
/// previously-saved address parts.
Future<_AddressLookupResult?> _addressLookupDialog(
  BuildContext context, {
  String street = '',
  String city = '',
  String state = '',
  String zip = '',
}) {
  return showDialog<_AddressLookupResult>(
    context: context,
    builder: (context) => _AddressLookupDialog(
      initialStreet: street,
      initialCity: city,
      initialState: state,
      initialZip: zip,
    ),
  );
}

class _AddressLookupDialog extends StatefulWidget {
  final String initialStreet;
  final String initialCity;
  final String initialState;
  final String initialZip;
  const _AddressLookupDialog({
    required this.initialStreet,
    required this.initialCity,
    required this.initialState,
    required this.initialZip,
  });

  @override
  State<_AddressLookupDialog> createState() => _AddressLookupDialogState();
}

class _AddressLookupDialogState extends State<_AddressLookupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _street;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;

  bool _busy = false;
  bool _noMatch = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _street = TextEditingController(text: widget.initialStreet);
    _city = TextEditingController(text: widget.initialCity);
    _state = TextEditingController(text: widget.initialState);
    _zip = TextEditingController(text: widget.initialZip);
  }

  @override
  void dispose() {
    _street.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  _AddressLookupResult _result({double? latitude, double? longitude, String? matched}) {
    final composed = GeocodingService.oneLine(
      street: _street.text,
      city: _city.text,
      state: _state.text,
      zip: _zip.text,
    );
    return _AddressLookupResult(
      address: (matched != null && matched.isNotEmpty) ? matched : composed,
      street: _street.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      zip: _zip.text.trim(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _noMatch = false;
    });
    final navigator = Navigator.of(context);
    final result = await GeocodingService().geocode(
      street: _street.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      zip: _zip.text.trim(),
    );
    if (!mounted) return;
    if (result != null) {
      navigator.pop(_result(
        latitude: result.latitude,
        longitude: result.longitude,
        matched: result.matchedAddress,
      ));
    } else {
      setState(() {
        _busy = false;
        _noMatch = true;
        _error =
            'Could not find coordinates for that address (US addresses only). '
            'Check the fields, or use the address without coordinates.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find coordinates from address'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter a US street address. We\'ll look up its latitude and '
                  'longitude using the free U.S. Census geocoder.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _street,
                  decoration: _dec('Street address'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _city, decoration: _dec('City')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                          controller: _state,
                          decoration: _dec('State (e.g. MD)')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                          controller: _zip,
                          decoration: _dec('ZIP'),
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.orange)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_noMatch)
          TextButton(
            onPressed:
                _busy ? null : () => Navigator.pop(context, _result()),
            child: const Text('Use address anyway'),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : _lookup,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search, size: 18),
          label: const Text('Find coordinates'),
        ),
      ],
    );
  }
}

/// Editor for a "This Day in Wildcat History" fact. [seed] pre-fills the form
/// (e.g. from an On-This-Day suggestion).
Future<HistoryFact?> editHistoryFact(BuildContext context, HistoryFact? h) {
  final title = TextEditingController(text: h?.title);
  final fact = TextEditingController(text: h?.fact);
  final year = TextEditingController(text: h?.year?.toString() ?? '');
  final source = TextEditingController(text: h?.sourceUrl ?? '');
  final now = DateTime.now();
  var date = DateTime(2000, h?.month ?? now.month, h?.day ?? now.day);
  return _formDialog<HistoryFact>(
    context,
    title: h == null ? 'New History Fact' : 'Edit History Fact',
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
          StatefulBuilder(
            builder: (context, setLocal) => InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year, date.month, date.day),
                  firstDate: DateTime(now.year, 1, 1),
                  lastDate: DateTime(now.year, 12, 31),
                  helpText: 'Pick the month & day this fact belongs to',
                );
                if (picked != null) {
                  setLocal(() => date = DateTime(2000, picked.month, picked.day));
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Month & day',
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(DateFormat('MMMM d').format(date)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
              controller: year,
              decoration: _dec('Year (optional)'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextFormField(
              controller: fact,
              decoration: _dec('Fact'),
              maxLines: 4,
              validator: _required),
          const SizedBox(height: 12),
          TextFormField(
              controller: source,
              decoration: _dec('Source / more info URL (optional)'),
              keyboardType: TextInputType.url,
              validator: _optionalUrl),
          _actions(
            key,
            () => submit(HistoryFact(
              id: h?.id ?? 'new',
              title: title.text.trim(),
              fact: fact.text.trim(),
              month: date.month,
              day: date.day,
              year: int.tryParse(year.text.trim()),
              sourceUrl: source.text.trim().isEmpty ? null : source.text.trim(),
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- Event ---------------------------------------------------------------
Future<SchoolEvent?> editEvent(BuildContext context, SchoolEvent? e) {
  final title = TextEditingController(text: e?.title);
  final desc = TextEditingController(text: e?.description);
  final loc = TextEditingController(text: e?.location);
  final geo = TextEditingController(
      text: (e != null && e.hasGeo) ? '${e.latitude}, ${e.longitude}' : '');
  String category = e?.category ?? 'General';

  // Structured address parts, saved on the event and used to pre-fill the
  // address-lookup dialog.
  String street = e?.street ?? '';
  String city = e?.city ?? '';
  String state = e?.state ?? '';
  String zip = e?.zip ?? '';

  // Date/time state is owned here so the pickers can stay controlled. A null
  // time means "blank" (the event is all-day).
  DateTime? startDate = e?.startsAt == null
      ? null
      : DateTime(e!.startsAt!.year, e.startsAt!.month, e.startsAt!.day);
  int? startMin = e?.startsAt == null
      ? 18 * 60
      : (e!.allDay ? null : _roundToSlot(e.startsAt!));
  DateTime? endDate = e?.endsAt == null
      ? null
      : DateTime(e!.endsAt!.year, e.endsAt!.month, e.endsAt!.day);
  int? endMin =
      e?.endsAt == null ? 18 * 60 : (e!.allDay ? null : _roundToSlot(e.endsAt!));

  return _formDialog<SchoolEvent>(
    context,
    title: e == null ? 'New Event' : 'Edit Event',
    build: (key, submit) => StatefulBuilder(
      builder: (context, setLocal) {
        String? error;
        // All-day when a start date is set but its time was left blank.
        final bool allDay = startDate != null && startMin == null;

        DateTime? combine(DateTime? d, int? min) {
          if (d == null) return null;
          final m = allDay ? 0 : (min ?? 0);
          return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
        }

        void trySubmit() {
          if (!(key.currentState?.validate() ?? true)) return;
          final start = combine(startDate, startMin);
          final end = combine(endDate, endMin);
          if (start != null && end != null && end.isBefore(start)) {
            setLocal(() => error = 'End must be after the start.');
            return;
          }
          final (lat, lng) = _parseLatLng(geo.text);
          submit(SchoolEvent(
            id: e?.id ?? 'new',
            title: title.text.trim(),
            description: desc.text.trim(),
            location: loc.text.trim(),
            latitude: lat,
            longitude: lng,
            street: street,
            city: city,
            state: state,
            zip: zip,
            allDay: allDay,
            startsAt: start,
            endsAt: end,
            category: category,
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
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: _dec('Category'),
                items: [
                  for (final c in kEventCategories)
                    DropdownMenuItem(value: c.key, child: Text(c.key)),
                ],
                onChanged: (v) => setLocal(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              _DateTimePicker(
                label: 'Start Date',
                date: startDate,
                minutes: startMin,
                onDateChanged: (v) => setLocal(() => startDate = v),
                onTimeChanged: (v) => setLocal(() => startMin = v),
              ),
              const SizedBox(height: 12),
              _DateTimePicker(
                label: 'End Date',
                date: endDate,
                minutes: endMin,
                onDateChanged: (v) => setLocal(() => endDate = v),
                onTimeChanged: (v) => setLocal(() => endMin = v),
              ),
              if (allDay)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Time left blank — this is an all-day event.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                        controller: loc, decoration: _dec('Location Address')),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.outlined(
                      tooltip: 'Enter an address to find its coordinates',
                      icon: const Icon(Icons.add_location_alt_outlined),
                      onPressed: () async {
                        final result = await _addressLookupDialog(
                          context,
                          // Pre-fill from saved parts; fall back to the current
                          // Location Address text as the street line.
                          street: street.isNotEmpty ? street : loc.text.trim(),
                          city: city,
                          state: state,
                          zip: zip,
                        );
                        if (result == null) return;
                        setLocal(() {
                          street = result.street;
                          city = result.city;
                          state = result.state;
                          zip = result.zip;
                          if (result.address.isNotEmpty) {
                            loc.text = result.address;
                          }
                          if (result.latitude != null &&
                              result.longitude != null) {
                            geo.text =
                                '${result.latitude}, ${result.longitude}';
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: geo,
                decoration: _dec('Geolocation — latitude, longitude (optional)'),
                validator: _optionalLatLng,
              ),
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
              () => submit(
                // Preserve the detailed application fields via copyWith when
                // editing an existing request.
                (r ??
                        const FundingRequest(
                            id: 'new', title: '', description: ''))
                    .copyWith(
                  title: title.text.trim(),
                  description: desc.text.trim(),
                  amountRequested: double.tryParse(amount.text) ?? 0,
                  requestedBy: by.text.trim(),
                  status: status,
                ),
              ),
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

Future<Committee?> editCommittee(BuildContext context, Committee? c) {
  final title = TextEditingController(text: c?.title);
  final order = TextEditingController(text: (c?.order ?? 0).toString());
  final schedule = TextEditingController(text: c?.schedule);
  final description = TextEditingController(text: c?.description);
  final roles = TextEditingController(text: c?.teamRoles.join('\n'));
  final sections = TextEditingController(
    text: c?.sections
        .map((s) => s.body.isEmpty ? s.heading : '${s.heading} | ${s.body}')
        .join('\n'),
  );
  final highlight = TextEditingController(text: c?.highlight);
  final email = TextEditingController(text: c?.contactEmail);

  List<String> parseRoles() => roles.text
      .split('\n')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty)
      .toList();

  List<CommitteeSection> parseSections() => sections.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final i = line.indexOf('|');
        if (i < 0) return CommitteeSection(heading: line);
        return CommitteeSection(
          heading: line.substring(0, i).trim(),
          body: line.substring(i + 1).trim(),
        );
      })
      .toList();

  return _formDialog<Committee>(
    context,
    title: c == null ? 'New Committee' : 'Edit Committee',
    build: (key, submit) => Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
              controller: title,
              decoration: _dec('Committee name'),
              validator: _required),
          const SizedBox(height: 12),
          TextFormField(
              controller: order,
              decoration: _dec('Display order'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextFormField(
              controller: schedule,
              decoration: _dec('Schedule / when it runs (optional)')),
          const SizedBox(height: 12),
          TextFormField(
              controller: description,
              decoration: _dec('Intro description (optional)'),
              maxLines: 2),
          const SizedBox(height: 12),
          TextFormField(
              controller: roles,
              decoration:
                  _dec('Team roles — one per line'),
              maxLines: 6),
          const SizedBox(height: 12),
          TextFormField(
              controller: sections,
              decoration: _dec(
                  'Detail sections — one per line, "Heading | text" (optional)'),
              maxLines: 4),
          const SizedBox(height: 12),
          TextFormField(
              controller: highlight,
              decoration: _dec('Highlighted call-out (optional)'),
              maxLines: 2),
          const SizedBox(height: 12),
          TextFormField(
              controller: email,
              decoration: _dec('Contact email (optional)')),
          _actions(
            key,
            () => submit(Committee(
              id: c?.id ?? 'new',
              title: title.text.trim(),
              order: int.tryParse(order.text) ?? 0,
              schedule: schedule.text.trim(),
              description: description.text.trim(),
              teamRoles: parseRoles(),
              sections: parseSections(),
              highlight: highlight.text.trim(),
              contactEmail: email.text.trim(),
            )),
          ),
        ],
      ),
    ),
  );
}

// ---- Legal document ------------------------------------------------------
/// Full-screen editor for a legal/policy document (Terms of Use, Privacy
/// Policy). The body supports light markup: `# `/`## ` headings, `- ` bullets,
/// and inline `**bold**` / `_italic_`.
Future<LegalDocument?> editLegalDocument(
    BuildContext context, LegalDocument doc) {
  final title = TextEditingController(text: doc.title);
  final body = TextEditingController(text: doc.body);
  return showDialog<LegalDocument>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(doc.title.isEmpty ? 'Edit document' : 'Edit ${doc.title}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  LegalDocument(
                    id: doc.id,
                    title: title.text.trim(),
                    body: body.text,
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
              children: [
                TextField(
                  controller: title,
                  decoration: _dec('Document title'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Formatting: "# " and "## " for headings, "- " for bullets, '
                  '**bold** and _italic_ inline. Replace every [PLACEHOLDER] '
                  'before publishing, and have an attorney review.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  decoration: const InputDecoration(
                    labelText: 'Document body',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                  minLines: 20,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---- Gallery image -------------------------------------------------------
/// Editor for a shared media-library image. Handles picking and uploading the
/// image file (to Firebase Storage via [fs]) before returning the saved
/// [GalleryImage] with its download URL.
Future<GalleryImage?> editGalleryImage(
    BuildContext context, GalleryImage? g, FirestoreService fs) {
  return showDialog<GalleryImage>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _GalleryImageDialog(existing: g, fs: fs),
  );
}

class _GalleryImageDialog extends StatefulWidget {
  final GalleryImage? existing;
  final FirestoreService fs;
  const _GalleryImageDialog({required this.existing, required this.fs});

  @override
  State<_GalleryImageDialog> createState() => _GalleryImageDialogState();
}

class _GalleryImageDialogState extends State<_GalleryImageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late final TextEditingController _tags;

  Uint8List? _bytes; // newly picked image, not yet uploaded
  String _pickedName = 'image.jpg';
  int _sizeBytes = 0; // size of the picked image
  int? _width; // pixel dimensions of the picked image
  int? _height;
  bool _public = true; // shown on the public Gallery page
  bool _busy = false;
  String? _error;

  /// The Storage rule rejects images at or above this size.
  static const int _maxBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title);
    _caption = TextEditingController(text: widget.existing?.caption);
    _tags = TextEditingController(text: widget.existing?.tags.join(', ') ?? '');
    _public = widget.existing?.public ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      // Decode the (already resized) image to report its pixel dimensions.
      int? w, h;
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        w = frame.image.width;
        h = frame.image.height;
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        // Dimensions are best-effort; size still shows if decoding fails.
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _pickedName = picked.name;
        _sizeBytes = bytes.lengthInBytes;
        _width = w;
        _height = h;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not get image: $e');
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final existingUrl = widget.existing?.imageUrl ?? '';
    if (_bytes == null && existingUrl.isEmpty) {
      setState(() => _error = 'Choose an image first.');
      return;
    }
    if (_bytes != null && _sizeBytes >= _maxBytes) {
      setState(() =>
          _error = 'Image exceeds the 10 MB limit — choose a smaller one.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      var url = existingUrl;
      if (_bytes != null) {
        url = await widget.fs.uploadImage(
          _bytes!,
          _pickedName,
          'gallery',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      final tags = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final existing = widget.existing;
      // When a new file was picked, record its metadata; otherwise keep what
      // the existing image already had.
      navigator.pop(GalleryImage(
        id: existing?.id ?? 'new',
        title: _title.text.trim(),
        imageUrl: url,
        caption: _caption.text.trim(),
        tags: tags,
        uploadedAt: existing?.uploadedAt,
        fileName: _bytes != null ? _pickedName : (existing?.fileName ?? ''),
        width: _bytes != null ? _width : existing?.width,
        height: _bytes != null ? _height : existing?.height,
        sizeBytes: _bytes != null ? _sizeBytes : existing?.sizeBytes,
        public: _public,
      ));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  /// Shows the picked image's pixel dimensions and file size, warning when it
  /// exceeds the Storage upload limit.
  Widget _imageMeta(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mb = _sizeBytes / (1024 * 1024);
    final tooBig = _sizeBytes >= _maxBytes;
    final dims =
        (_width != null && _height != null) ? '$_width × $_height px' : null;
    final summary =
        [if (dims != null) dims, '${mb.toStringAsFixed(2)} MB'].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(summary,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          if (tooBig)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Exceeds the 10 MB upload limit — please choose a smaller image.',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingUrl = widget.existing?.imageUrl ?? '';
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Image' : 'Edit Image'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _bytes != null
                        ? Image.memory(_bytes!, fit: BoxFit.cover)
                        : existingUrl.isNotEmpty
                            ? MediaImage(existingUrl, fit: BoxFit.cover)
                            : Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.06),
                                child: const Center(
                                  child: Icon(Icons.image_outlined, size: 48),
                                ),
                              ),
                  ),
                ),
                if (_bytes != null) _imageMeta(context),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _title,
                    decoration: _dec('Title'),
                    validator: _required),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _caption,
                    decoration: _dec('Caption (optional)'),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _tags,
                    decoration: _dec('Tags (comma-separated, optional)')),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _public,
                  onChanged:
                      _busy ? null : (v) => setState(() => _public = v),
                  secondary:
                      Icon(_public ? Icons.public : Icons.lock_outline),
                  title: const Text('Show on public gallery'),
                  subtitle: Text(_public
                      ? 'Visible to everyone on the Gallery page.'
                      : 'Hidden from the public Gallery — visible only to '
                          'managers here.'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
