import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/desk_service.dart';

class SharedDesksScreen extends StatefulWidget {
  const SharedDesksScreen({super.key});

  @override
  State<SharedDesksScreen> createState() => _SharedDesksScreenState();
}

class _SharedDesksScreenState extends State<SharedDesksScreen> {
  final _service = DeskService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _future = _service.fetchMyDesks();

  Future<void> _reload() async {
    setState(_refresh);
    await _future;
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm({required String title, required String message, String action = 'Continue', bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _createDesk() async {
    final name = TextEditingController();
    String type = 'family';
    bool saving = false;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create a Shared Desk'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Desk name')),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'family', child: Text('Family')),
                  DropdownMenuItem(value: 'business', child: Text('Business')),
                  DropdownMenuItem(value: 'roommates', child: Text('Roommates')),
                  DropdownMenuItem(value: 'custom', child: Text('Other')),
                ],
                onChanged: saving ? null : (value) => setLocal(() => type = value ?? 'custom'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().length < 2) return;
                      setLocal(() => saving = true);
                      try {
                        await _service.createDesk(name: name.text, type: type);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setLocal(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create desk: $e')));
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (created == true) {
      await _reload();
      _message('Shared Desk created.');
    }
  }

  Future<void> _joinDesk() async {
    final code = TextEditingController();
    bool saving = false;
    final joined = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Join a Shared Desk'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. A1B2C3D4'),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (code.text.trim().isEmpty) return;
                      setLocal(() => saving = true);
                      try {
                        await _service.joinDesk(code.text);
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setLocal(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join desk: $e')));
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    if (joined == true) {
      await _reload();
      _message('You joined the Shared Desk.');
    }
  }

  Future<void> _showMembers(Map<String, dynamic> desk) async {
    List<Map<String, dynamic>> members;
    try {
      members = await _service.fetchDeskMembers(desk['id'] as String);
    } catch (e) {
      _message('Could not load members: $e');
      return;
    }
    if (!mounted) return;

    final callerRole = '${desk['role']}';
    final isOwner = callerRole == 'owner';
    final canManage = callerRole == 'owner' || callerRole == 'admin';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Row(children: [
            Expanded(child: Text('${desk['name']} members')),
            Chip(label: Text(callerRole)),
          ]),
          content: SizedBox(
            width: 520,
            child: members.isEmpty
                ? const Text('No members found.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final role = '${member['role']}';
                      final isMe = member['is_me'] == true;
                      final userId = member['user_id'] as String;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text(_initials('${member['full_name']}'))),
                        title: Text('${member['full_name']}${isMe ? ' (You)' : ''}'),
                        subtitle: Text(_roleDescription(role)),
                        trailing: (!isMe && canManage && role != 'owner')
                            ? PopupMenuButton<String>(
                                onSelected: (value) async {
                                  try {
                                    if (value == 'remove') {
                                      final ok = await _confirm(
                                        title: 'Remove member?',
                                        message: '${member['full_name']} will immediately lose access to this desk and its desk-only content.',
                                        action: 'Remove',
                                        destructive: true,
                                      );
                                      if (!ok) return;
                                      await _service.removeMember(deskId: desk['id'] as String, userId: userId);
                                      members = await _service.fetchDeskMembers(desk['id'] as String);
                                      setLocal(() {});
                                    } else if (isOwner) {
                                      await _service.setMemberRole(deskId: desk['id'] as String, userId: userId, role: value);
                                      members = await _service.fetchDeskMembers(desk['id'] as String);
                                      setLocal(() {});
                                    }
                                  } catch (e) {
                                    _message('Could not update member: $e');
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (isOwner) ...const [
                                    PopupMenuItem(value: 'admin', child: Text('Make admin')),
                                    PopupMenuItem(value: 'member', child: Text('Make member')),
                                    PopupMenuItem(value: 'viewer', child: Text('Make viewer')),
                                  ],
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'remove', child: Text('Remove from desk')),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<void> _rotateInvite(Map<String, dynamic> desk) async {
    final ok = await _confirm(
      title: 'Rotate invite code?',
      message: 'The current invite code will stop working immediately. Existing members will not be affected.',
      action: 'Rotate code',
    );
    if (!ok) return;
    try {
      final code = await _service.rotateInvite(desk['id'] as String);
      await _reload();
      await Clipboard.setData(ClipboardData(text: code));
      _message('New invite code copied to clipboard.');
    } catch (e) {
      _message('Could not rotate invite code: $e');
    }
  }

  Future<void> _leaveDesk(Map<String, dynamic> desk) async {
    final ok = await _confirm(
      title: 'Leave ${desk['name']}?',
      message: 'You will lose access to desk-only documents, bills and tasks. You can rejoin later with a valid invite.',
      action: 'Leave desk',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.leaveDesk(desk['id'] as String);
      await _reload();
      _message('You left the Shared Desk.');
    } catch (e) {
      _message('Could not leave desk: $e');
    }
  }

  Future<void> _deleteDesk(Map<String, dynamic> desk) async {
    final ok = await _confirm(
      title: 'Delete ${desk['name']}?',
      message: 'This permanently deletes the desk and removes its memberships. Desk-linked records may also be deleted by database cascade rules. This cannot be undone.',
      action: 'Delete desk',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteDesk(desk['id'] as String);
      await _reload();
      _message('Shared Desk deleted.');
    } catch (e) {
      _message('Could not delete desk: $e');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'owner': return 'Owner · full control';
      case 'admin': return 'Admin · can manage members and invites';
      case 'viewer': return 'Viewer · cannot create desk-linked content';
      default: return 'Member · normal participant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shared Desks', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text('Family, business and trusted groups with clear ownership and permissions.'),
                ],
              ),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: _joinDesk, icon: const Icon(Icons.login), label: const Text('Join desk')),
                FilledButton.icon(onPressed: _createDesk, icon: const Icon(Icons.add), label: const Text('Create desk')),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return _MessageCard(icon: Icons.cloud_off, title: 'Could not load desks', message: '${snapshot.error}', onRetry: _reload);
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return _MessageCard(
                  icon: Icons.groups_2_outlined,
                  title: 'No Shared Desks yet',
                  message: 'Create a Family Desk or join someone using their invite code.',
                  actionLabel: 'Create your first desk',
                  onAction: _createDesk,
                );
              }
              return LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 950 ? 3 : constraints.maxWidth >= 600 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final desk = rows[index];
                    final role = '${desk['role']}';
                    final invite = desk['invite_code']?.toString();
                    final canManage = role == 'owner' || role == 'admin';
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showMembers(desk),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(child: Icon(_iconForType('${desk['type']}'))),
                              const Spacer(),
                              Chip(label: Text(role)),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'members') await _showMembers(desk);
                                  if (value == 'rotate') await _rotateInvite(desk);
                                  if (value == 'leave') await _leaveDesk(desk);
                                  if (value == 'delete') await _deleteDesk(desk);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'members', child: Text('View members')),
                                  if (canManage) const PopupMenuItem(value: 'rotate', child: Text('Rotate invite code')),
                                  if (role != 'owner') const PopupMenuItem(value: 'leave', child: Text('Leave desk')),
                                  if (role == 'owner') const PopupMenuItem(value: 'delete', child: Text('Delete desk')),
                                ],
                              ),
                            ]),
                            const Spacer(),
                            Text('${desk['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${desk['type']} desk · Tap to manage members'),
                            const SizedBox(height: 12),
                            if (invite != null && invite.isNotEmpty)
                              Row(children: [
                                const Icon(Icons.key, size: 17),
                                const SizedBox(width: 6),
                                Expanded(child: SelectableText(invite, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1))),
                                IconButton(
                                  tooltip: 'Copy invite',
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: invite));
                                    _message('Invite code copied.');
                                  },
                                  icon: const Icon(Icons.copy, size: 19),
                                ),
                              ])
                            else
                              const Row(children: [
                                Icon(Icons.lock_outline, size: 17),
                                SizedBox(width: 6),
                                Expanded(child: Text('Invite code is managed by the desk owner/admin.')),
                              ]),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              });
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'family': return Icons.family_restroom;
      case 'business': return Icons.business_center_outlined;
      case 'roommates': return Icons.home_outlined;
      default: return Icons.groups_outlined;
    }
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: () => onRetry!(), icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}
