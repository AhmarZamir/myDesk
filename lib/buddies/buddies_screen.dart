import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/buddy_service.dart';
import '../services/desk_service.dart';

class BuddiesScreen extends StatefulWidget {
  const BuddiesScreen({super.key});

  @override
  State<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends State<BuddiesScreen> {
  final _service = BuddyService();
  final _deskService = DeskService();
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
              const Text('Send this link to someone you trust. After they sign in, the connection will be added to both Buddy lists.'),
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

  Future<void> _addToDesk(Map<String, dynamic> buddy) async {
    final desks = (await _deskService.fetchMyDesks())
        .where((d) => d['role'] == 'owner' || d['role'] == 'admin')
        .toList();
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
        ) ??
        false;
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
                  subtitle: const Text('Connected Buddy · available for direct sharing and Khata'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'desk') await _addToDesk(buddy);
                      if (value == 'remove') await _remove(buddy);
                    },
                    itemBuilder: (_) => const [
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
