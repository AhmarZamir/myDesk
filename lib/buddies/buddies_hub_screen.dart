import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'buddies_screen.dart';

class BuddiesHubScreen extends StatefulWidget {
  const BuddiesHubScreen({super.key});
  @override State<BuddiesHubScreen> createState() => _BuddiesHubScreenState();
}

class _BuddiesHubScreenState extends State<BuddiesHubScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = Future.wait([_service.buddies(), _service.documents(), _service.khataEntries(), _service.desks()]);
  void _refresh() => setState(_reload);

  Future<void> _manage() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: BuddiesScreen()))));
    _refresh();
  }

  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('myDesk Buddies', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('People you trust and collaborate with across myDesk.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
      FilledButton.icon(onPressed: _manage, icon: const Icon(Icons.person_add_alt_1), label: const Text('Invite / Manage')),
    ]),
    const SizedBox(height: 22),
    FutureBuilder<List<dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
      if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load Buddies: ${snap.error}')));
      final buddies = List<Map<String,dynamic>>.from(snap.data![0] as List); final docs = List<Map<String,dynamic>>.from(snap.data![1] as List); final khata = List<Map<String,dynamic>>.from(snap.data![2] as List); final desks = List<Map<String,dynamic>>.from(snap.data![3] as List);
      if (buddies.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(36), child: Column(children: [const Icon(Icons.people_outline, size: 46), const SizedBox(height: 10), const Text('No Buddies yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 12), FilledButton.icon(onPressed: _manage, icon: const Icon(Icons.person_add_alt_1), label: const Text('Invite Buddy'))])));
      return LayoutBuilder(builder: (context, constraints) { final cols = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 580 ? 2 : 1; return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: buddies.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: cols == 1 ? 3 : 1.35), itemBuilder: (_, i) {
        final b = buddies[i]; final id = '${b['user_id']}'; final entries = khata.where((e) => '${e['buddy_user_id']}' == id).toList();
        return Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => showDialog<void>(context: context, builder: (_) => _BuddyProfileDialog(buddy: b, entries: entries, docs: docs, desks: desks)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString(), radius: 24), const SizedBox(width: 12), Expanded(child: Text('${b['full_name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), const Icon(Icons.chevron_right)]), const Spacer(), Text('${entries.length} Khata entries', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 4), const Text('Tap to view relationship profile'),
        ]))));
      }); });
    }),
  ]);
}

class _BuddyProfileDialog extends StatelessWidget {
  final Map<String,dynamic> buddy; final List<Map<String,dynamic>> entries; final List<Map<String,dynamic>> docs; final List<Map<String,dynamic>> desks;
  const _BuddyProfileDialog({required this.buddy, required this.entries, required this.docs, required this.desks});
  @override Widget build(BuildContext context) {
    double receive = 0, give = 0;
    for (final e in entries.where((e) => e['status'] != 'settled')) { final creatorReceivable = e['direction'] == 'receivable'; final mine = e['created_by'] != buddy['user_id']; final forMe = mine ? creatorReceivable : !creatorReceivable; final v = double.tryParse('${e['amount']}') ?? 0; if (forMe) receive += v; else give += v; }
    return AlertDialog(title: Row(children: [_Avatar(name: '${buddy['full_name']}', url: buddy['avatar_url']?.toString(), radius: 22), const SizedBox(width: 12), Expanded(child: Text('${buddy['full_name']}', style: const TextStyle(fontWeight: FontWeight.w900)))]), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [_Info(label: 'Khata entries', value: '${entries.length}'), _Info(label: 'They owe you', value: 'Rs. ${receive.toStringAsFixed(0)}'), _Info(label: 'You owe them', value: 'Rs. ${give.toStringAsFixed(0)}')]),
      const SizedBox(height: 18), const Text('Relationship tools', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Use Invite / Manage Buddies to share a document directly, add this Buddy to a Shared Desk, or manage the connection.'),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);
  }
}

class _Info extends StatelessWidget { final String label; final String value; const _Info({required this.label, required this.value}); @override Widget build(BuildContext context) => Container(width: 145, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])); }
class _Avatar extends StatelessWidget { final String name; final String? url; final double radius; const _Avatar({required this.name, this.url, this.radius = 20}); @override Widget build(BuildContext context) { if (url != null && url!.isNotEmpty) return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url!)); return CircleAvatar(radius: radius, child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase())); } }
