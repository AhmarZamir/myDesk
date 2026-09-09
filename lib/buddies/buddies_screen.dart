import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/buddy_service.dart';
import '../services/desk_service.dart';
import '../services/workspace_service.dart';

class BuddiesScreen extends StatefulWidget {
  const BuddiesScreen({super.key});

  @override
  State<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends State<BuddiesScreen> {
  final _service = BuddyService();
  final _deskService = DeskService();
  final _workspace = WorkspaceService();
  late Future<List<Map<String, dynamic>>> _future;
  bool _handledReferral = false;

  @override
  void initState() {
    super.initState();
    _future = _service.buddies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _acceptReferralFromUrl());
  }

  void _refresh() => setState(() => _future = _service.buddies());

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _acceptReferralFromUrl() async {
    if (_handledReferral) return;
    _handledReferral = true;
    final token = Uri.base.queryParameters['buddy'];
    if (token == null || token.trim().isEmpty) return;
    try {
      await _service.acceptInvite(token);
      _refresh();
      _message('Buddy connected successfully.');
    } catch (e) {
      _message('Could not accept Buddy invite: $e');
    }
  }

  Future<void> _createReferral() async {
    try {
      final token = await _service.createInviteToken();
      final link = _service.referralLink(token);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite a myDesk Buddy'),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Send this link to someone you trust. After they sign in, the connection is available to both of you across myDesk.'),
              const SizedBox(height: 14),
              SelectableText(link, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Code: $token'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) Navigator.pop(context);
                _message('Buddy referral link copied.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy link'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('Could not create referral link: $e');
    }
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect with a Buddy'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Referral code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim().isNotEmpty), child: const Text('Connect')),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await _service.acceptInvite(controller.text);
        _refresh();
        _message('Buddy connected successfully.');
      } catch (e) {
        _message('Could not connect Buddy: $e');
      }
    }
    controller.dispose();
  }

  Future<void> _shareDocument(Map<String, dynamic> buddy) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;
    final file = picked.files.single;
    if (file.size > WorkspaceService.maxDocumentBytes) {
      _message('Files must be 15 MB or smaller.');
      return;
    }

    final title = TextEditingController(text: file.name);
    String category = 'other';
    DateTime? expiresAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Share with ${buddy['full_name']}'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const ['id', 'certificate', 'property', 'medical', 'receipt', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setLocal(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(expiresAt == null ? 'No expiry date' : 'Expires ${expiresAt!.toLocal().toString().split(' ').first}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (pickedDate != null) setLocal(() => expiresAt = pickedDate);
                },
              ),
              const SizedBox(height: 8),
              const Text('This is a direct Buddy share. No Shared Desk or group is required.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: title.text.trim().isEmpty ? null : () => Navigator.pop(context, true), child: const Text('Share')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await _workspace.uploadDocument(
          title: title.text,
          category: category,
          fileName: file.name,
          bytes: file.bytes!,
          visibility: 'custom',
          recipientIds: [buddy['user_id'] as String],
          expiresAt: expiresAt,
        );
        _message('Document shared directly with ${buddy['full_name']}.');
      } catch (e) {
        _message('Could not share document: $e');
      }
    }
    title.dispose();
  }

  Future<void> _addToDesk(Map<String, dynamic> buddy) async {
    final desks = (await _deskService.fetchMyDesks()).where((d) => d['role'] == 'owner' || d['role'] == 'admin').toList();
    if (!mounted) return;
    if (desks.isEmpty) {
      _message('You need an owned/admin Shared Desk first.');
      return;
    }
    String? deskId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Add ${buddy['full_name']} to a desk'),
          content: DropdownButtonFormField<String>(
            initialValue: deskId,
            decoration: const InputDecoration(labelText: 'Shared Desk'),
            items: desks.map((d) => DropdownMenuItem<String>(value: d['id'] as String, child: Text('${d['name']}'))).toList(),
            onChanged: (v) => setLocal(() => deskId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: deskId == null ? null : () => Navigator.pop(context, true), child: const Text('Add member')),
          ],
        ),
      ),
    );
    if (ok == true && deskId != null) {
      try {
        await _service.addBuddyToDesk(deskId: deskId!, buddyUserId: buddy['user_id'] as String);
        _message('Buddy added to the Shared Desk.');
      } catch (e) {
        _message('Could not add Buddy: $e');
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> buddy) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove ${buddy['full_name']}?'),
            content: const Text('They will no longer appear in your Buddy list. Existing Shared Desk memberships are not changed automatically.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
            ],
          ),
        ) ?? false;
    if (!ok) return;
    try {
      await _service.removeBuddy(buddy['user_id'] as String);
      _refresh();
    } catch (e) {
      _message('Could not remove Buddy: $e');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('myDesk Buddies', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Trusted people you can reuse for direct sharing, Khata and Shared Desks.'),
            ]),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(onPressed: _enterCode, icon: const Icon(Icons.link), label: const Text('Enter code')),
              FilledButton.icon(onPressed: _createReferral, icon: const Icon(Icons.person_add_alt_1), label: const Text('Invite Buddy')),
            ]),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(28), child: Text('Could not load Buddies: ${snap.error}')));
            final buddies = snap.data ?? [];
            if (buddies.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(children: [
                    const Icon(Icons.people_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('No Buddies yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Invite a trusted person once, then reuse that connection anywhere in myDesk.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(onPressed: _createReferral, icon: const Icon(Icons.person_add_alt_1), label: const Text('Invite your first Buddy')),
                  ]),
                ),
              );
            }
            return Column(
              children: buddies.map((buddy) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Text(_initials('${buddy['full_name']}'))),
                  title: Text('${buddy['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Connected Buddy · direct sharing · shared Khata · reusable in desks'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'share') await _shareDocument(buddy);
                      if (value == 'desk') await _addToDesk(buddy);
                      if (value == 'remove') await _remove(buddy);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'share', child: Text('Share document directly')),
                      PopupMenuItem(value: 'desk', child: Text('Add to Shared Desk')),
                      PopupMenuItem(value: 'remove', child: Text('Remove Buddy')),
                    ],
                  ),
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}
