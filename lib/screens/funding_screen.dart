import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
                          if (r.imageUrl != null &&
                              r.imageUrl!.startsWith('http')) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                r.imageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Pill('\$${r.amountRequested.toStringAsFixed(0)}',
                                  icon: Icons.attach_money),
                              if (r.groupType.isNotEmpty)
                                Pill(
                                    r.groupType == 'sport' ? 'Sport' : 'Club',
                                    icon: r.groupType == 'sport'
                                        ? Icons.sports
                                        : Icons.groups),
                              if (r.studentCount > 0)
                                Pill('${r.studentCount} students',
                                    icon: Icons.people_outline),
                              if (r.requestedBy.isNotEmpty)
                                Text('by ${r.requestedBy}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
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
    showDialog(
      context: context,
      builder: (_) => _FundingFormDialog(fs: fs, user: user),
    );
  }
}

/// New-funding-request form with an optional photo (choose from library or take
/// with the camera). The image is uploaded to Storage and linked to the request.
class _FundingFormDialog extends StatefulWidget {
  final FirestoreService fs;
  final AppUser user;
  const _FundingFormDialog({required this.fs, required this.user});

  @override
  State<_FundingFormDialog> createState() => _FundingFormDialogState();
}

/// Options for "contribution to Booster fundraising" (check all that apply).
const List<String> kFundraisingContributions = [
  'Concession Stand',
  'Annual Gala / Auction',
  'Spirit Wear Sales',
  'Corporate Sponsorships',
  'Membership Drive',
  'Fun Run / 5K',
  'Restaurant / Dining Nights',
  'Other',
];

class _FundingFormDialogState extends State<_FundingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameC = TextEditingController(); // Sport team or club name
  final _coachC = TextEditingController();
  final _coachEmailC = TextEditingController();
  final _parentC = TextEditingController();
  final _parentEmailC = TextEditingController();
  final _studentsC = TextEditingController();
  final _amountC = TextEditingController();
  final _usageC = TextEditingController();
  final _prevC = TextEditingController();
  final _membersC = TextEditingController();

  String _groupType = 'sport'; // 'sport' | 'club'
  bool _metLeadership = false;
  final Set<String> _contributions = {};

  Uint8List? _imageBytes;
  String _imageName = 'photo.jpg';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nameC, _coachC, _coachEmailC, _parentC, _parentEmailC,
      _studentsC, _amountC, _usageC, _prevC, _membersC,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _email(String? v) =>
      (v == null || !v.contains('@') || !v.contains('.'))
          ? 'Enter a valid email'
          : null;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    } catch (e) {
      setState(() => _error = 'Could not get photo: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Please complete the required fields.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await widget.fs
            .uploadImage(_imageBytes!, _imageName, 'funding', now.millisecondsSinceEpoch);
      }
      await widget.fs.submitFundingRequest(FundingRequest(
        id: 'new',
        title: _nameC.text.trim(),
        description: _usageC.text.trim(),
        amountRequested: double.tryParse(_amountC.text.trim()) ?? 0,
        requestedBy: _coachC.text.trim(),
        status: 'pending',
        submittedAt: now,
        imageUrl: imageUrl,
        groupType: _groupType,
        coachName: _coachC.text.trim(),
        coachEmail: _coachEmailC.text.trim(),
        parentName: _parentC.text.trim(),
        parentEmail: _parentEmailC.text.trim(),
        studentCount: int.tryParse(_studentsC.text.trim()) ?? 0,
        metWithLeadership: _metLeadership,
        previousRequests: _prevC.text.trim(),
        boosterMembersInfo: _membersC.text.trim(),
        fundraisingContributions: _contributions.toList(),
      ));
      navigator.pop();
      messenger.showSnackBar(
          const SnackBar(content: Text('Funding request submitted.')));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Submit failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSport = _groupType == 'sport';
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Funding Request'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Request Booster Club funding for your team or club.',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'sport',
                              label: Text('Sport Team'),
                              icon: Icon(Icons.sports)),
                          ButtonSegment(
                              value: 'club',
                              label: Text('Club'),
                              icon: Icon(Icons.groups)),
                        ],
                        selected: {_groupType},
                        onSelectionChanged: (s) =>
                            setState(() => _groupType = s.first),
                      ),
                      const SizedBox(height: 16),
                      _field(_nameC, 'Sport Team or Club Name', max: 200,
                          validator: _req),
                      _field(_coachC, 'Coach / Sponsor Name', max: 100,
                          validator: _req),
                      _field(_coachEmailC, 'Coach / Sponsor Email',
                          keyboard: TextInputType.emailAddress,
                          validator: _email),
                      _field(_parentC, 'Parent Commissioner Name', max: 100,
                          validator: _req),
                      _field(_parentEmailC, 'Parent Commissioner Email',
                          keyboard: TextInputType.emailAddress,
                          validator: _email),
                      Row(
                        children: [
                          Expanded(
                            child: _field(_studentsC,
                                'Total Student Participants',
                                keyboard: TextInputType.number,
                                validator: (v) =>
                                    (int.tryParse(v ?? '') == null)
                                        ? 'Enter a number'
                                        : null),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(_amountC, 'Requested Amount',
                                prefix: '\$ ',
                                keyboard: TextInputType.number,
                                validator: (v) =>
                                    (double.tryParse(v ?? '') == null)
                                        ? 'Enter an amount'
                                        : null),
                          ),
                        ],
                      ),
                      _field(_usageC,
                          'How will your group use the funds? (include a link to pictures or a website)',
                          max: 200, lines: 3, validator: _req),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _metLeadership,
                        onChanged: (v) => setState(() => _metLeadership = v),
                        title: Text(isSport
                            ? 'Have you met with the AD to discuss your request?'
                            : 'Have you met with the Asst. Principal to discuss your request?'),
                      ),
                      _field(_prevC,
                          'Previous Request History (date, amount, description)',
                          max: 300, lines: 3),
                      _field(_membersC,
                          'How many parents of your group are current Booster Club members this year?',
                          max: 100),
                      const SizedBox(height: 8),
                      Text(
                          'Describe your team/club\'s contribution to Booster fundraising in the past (check all that apply):',
                          style: Theme.of(context).textTheme.labelLarge),
                      for (final opt in kFundraisingContributions)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _contributions.contains(opt),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _contributions.add(opt);
                            } else {
                              _contributions.remove(opt);
                            }
                          }),
                          title: Text(opt),
                        ),
                      const SizedBox(height: 16),
                      Text('Photo (optional)',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      if (_imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_imageBytes!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Choose'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Take photo'),
                            ),
                          ),
                        ],
                      ),
                      if (_imageBytes != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _imageBytes = null),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Remove photo'),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Submitting…' : 'Submit request'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int? max,
    int lines = 1,
    String? prefix,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLength: max,
        maxLines: lines,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          alignLabelWithHint: lines > 1,
        ),
      ),
    );
  }
}
