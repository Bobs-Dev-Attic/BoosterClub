import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/audit.dart';
import '../../models/permissions.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';

/// Web Admin screen to assign roles and delegate granular permissions
/// (optionally time-limited) to users. Every change is audit-logged.
class UsersAdmin extends StatelessWidget {
  final FirestoreService fs;
  final AppUser actor;
  const UsersAdmin({super.key, required this.fs, required this.actor});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Users & Roles',
            subtitle:
                'Assign a base role and delegate specific permissions, with '
                'optional expiry. All changes are recorded in the audit log.',
          ),
          StreamListView<AppUser>(
            stream: fs.users(),
            emptyMessage: 'No users found.',
            builder: (context, users) => Column(
              children: [
                for (final u in users)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(u.displayName.isNotEmpty
                            ? u.displayName[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(u.displayName),
                      subtitle: Text(
                          '${u.email}\n${u.effectivePermissions().length} permissions'),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Pill(u.role.label, icon: Icons.badge_outlined),
                          TextButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _UserEditor(
                                  fs: fs, actor: actor, target: u),
                            ),
                            child: const Text('Manage'),
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
}

class _UserEditor extends StatefulWidget {
  final FirestoreService fs;
  final AppUser actor;
  final AppUser target;
  const _UserEditor(
      {required this.fs, required this.actor, required this.target});

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late UserRole _role = widget.target.role;
  // Delegated grants (perm -> expiry; AppUser.never means permanent).
  late final Map<String, DateTime> _grants = Map.of(widget.target.grants);
  bool _busy = false;

  bool _roleHas(String perm) => rolePermissions(_role).contains(perm);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage ${widget.target.displayName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Base role'),
                items: [
                  for (final r in UserRole.values)
                    if (r != UserRole.guest)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() {
                  _role = v ?? _role;
                  // Drop delegated grants now covered by the new role.
                  _grants.removeWhere((k, _) => _roleHas(k));
                }),
              ),
              const SizedBox(height: 16),
              Text('Permissions',
                  style: Theme.of(context).textTheme.titleSmall),
              const Text(
                'Locked items come from the base role. Toggle others to delegate; '
                'set an expiry for temporary access.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final perm in kPermissions) _permRow(perm),
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

  Widget _permRow(String perm) {
    final label = kPermissionLabels[perm] ?? perm;
    final byRole = _roleHas(perm);
    final granted = _grants.containsKey(perm);
    final expiry = _grants[perm];
    final permanent = expiry == AppUser.never;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: byRole || granted,
          onChanged: byRole
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _grants[perm] = AppUser.never;
                    } else {
                      _grants.remove(perm);
                    }
                  }),
          title: Text(label),
          subtitle: byRole
              ? const Text('Included by role')
              : granted
                  ? Text(permanent
                      ? 'Delegated · no expiry'
                      : 'Delegated · until ${DateFormat('MMM d, y').format(expiry!)}')
                  : null,
          secondary: byRole
              ? const Icon(Icons.lock_outline)
              : null,
        ),
        if (!byRole && granted)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No expiry'),
                  selected: permanent,
                  onSelected: (_) =>
                      setState(() => _grants[perm] = AppUser.never),
                ),
                ChoiceChip(
                  label: Text(permanent
                      ? 'Set expiry…'
                      : DateFormat('MMM d, y').format(expiry!)),
                  selected: !permanent,
                  onSelected: (_) => _pickExpiry(perm),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickExpiry(String perm) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Permission expires at end of day',
    );
    if (picked != null) {
      setState(() => _grants[perm] =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final orig = widget.target;
    final actions = <String>[];

    if (_role != orig.role) {
      actions.add('Role: ${orig.role.label} → ${_role.label}');
    }
    // Compare delegated grants.
    final origG = orig.grants;
    for (final e in _grants.entries) {
      final label = kPermissionLabels[e.key] ?? e.key;
      final expStr = e.value == AppUser.never
          ? 'no expiry'
          : 'until ${DateFormat('MMM d, y').format(e.value)}';
      if (!origG.containsKey(e.key)) {
        actions.add('Granted "$label" ($expStr)');
      } else if (origG[e.key] != e.value) {
        actions.add('Updated "$label" expiry ($expStr)');
      }
    }
    for (final k in origG.keys) {
      if (!_grants.containsKey(k)) {
        actions.add('Revoked "${kPermissionLabels[k] ?? k}"');
      }
    }

    if (actions.isEmpty) {
      setState(() => _busy = false);
      navigator.pop();
      return;
    }

    try {
      await widget.fs.saveUserAdmin(
        orig.copyWith(role: _role, grants: _grants),
        actor: widget.actor,
        actions: actions,
      );
      navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Text('Saved ${actions.length} change(s).')));
    } catch (e) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}

/// Read-only audit log of role/permission changes.
class AuditLogView extends StatelessWidget {
  final FirestoreService fs;
  const AuditLogView({super.key, required this.fs});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Audit Log',
            subtitle: 'Every role and permission change, most recent first.',
          ),
          StreamListView<AuditEntry>(
            stream: fs.auditLog(),
            emptyIcon: Icons.history,
            emptyMessage: 'No changes recorded yet.',
            builder: (context, entries) => Column(
              children: [
                for (final e in entries)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: Text(e.details),
                      subtitle: Text(
                          '${e.actorName} → ${e.targetName}'
                          '${e.at != null ? ' · ${DateFormat('MMM d, y · h:mm a').format(e.at!)}' : ''}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
