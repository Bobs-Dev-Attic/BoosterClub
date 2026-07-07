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

class _FundingFormDialogState extends State<_FundingFormDialog> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _amountC = TextEditingController();
  late final _byC =
      TextEditingController(text: widget.user.organization ?? '');
  final _formKey = GlobalKey<FormState>();

  Uint8List? _imageBytes;
  String _imageName = 'photo.jpg';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _amountC.dispose();
    _byC.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
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
    if (!_formKey.currentState!.validate()) return;
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
        imageUrl = await widget.fs.uploadImage(
          _imageBytes!,
          _imageName,
          'funding',
          now.millisecondsSinceEpoch,
        );
      }
      await widget.fs.submitFundingRequest(FundingRequest(
        id: 'new',
        title: _titleC.text.trim(),
        description: _descC.text.trim(),
        amountRequested: double.parse(_amountC.text.trim()),
        requestedBy: _byC.text.trim(),
        status: 'pending',
        submittedAt: now,
        imageUrl: imageUrl,
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
    return AlertDialog(
      title: const Text('New Funding Request'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleC,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _byC,
                  decoration:
                      const InputDecoration(labelText: 'Team / Club'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Amount requested', prefixText: '\$ '),
                  validator: (v) => (double.tryParse(v ?? '') == null)
                      ? 'Enter a number'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descC,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Text('Photo (optional)',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                if (_imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_imageBytes!,
                        height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _pickImage(ImageSource.camera),
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
                  const SizedBox(height: 10),
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
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
