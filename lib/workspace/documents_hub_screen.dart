import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'documents_screen.dart';

class DocumentsHubScreen extends StatefulWidget {
  const DocumentsHubScreen({super.key});
  @override State<DocumentsHubScreen> createState() => _DocumentsHubScreenState();
}

class _DocumentsHubScreenState extends State<DocumentsHubScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;
  String _filter = 'all';

  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = Future.wait([_service.documents(), _service.desks()]);
  void _refresh() => setState(_reload);

  Future<void> _openManager() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: DocumentsScreen()))));
    _refresh();
  }

  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Documents & Vault', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Browse information by Personal Desk or any Shared Desk.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        FilledButton.icon(onPressed: _openManager, icon: const Icon(Icons.upload_file), label: const Text('Upload / Manage')),
      ]),
      const SizedBox(height: 22),
      FutureBuilder<List<dynamic>>(future: _future, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load documents: ${snap.error}')));
        final docs = List<Map<String,dynamic>>.from(snap.data![0] as List);
        final desks = List<Map<String,dynamic>>.from(snap.data![1] as List);
        final filters = <String,String>{'all':'All','personal':'My Desk', for (final d in desks) '${d['id']}':'${d['name']}'};
        if (!filters.containsKey(_filter)) _filter = 'all';
        final visible = docs.where((d) {
          if (_filter == 'all') return true;
          if (_filter == 'personal') return d['desk_id'] == null;
          return '${d['desk_id']}' == _filter;
        }).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Wrap(spacing: 8, children: filters.entries.map((e) => ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key))).toList())),
          const SizedBox(height: 18),
          if (visible.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(34), child: Center(child: Text('No documents in this section.')))),
          ...visible.map((doc) {
            final desk = desks.where((d) => '${d['id']}' == '${doc['desk_id']}').toList();
            final workspace = doc['desk_id'] == null ? 'My Desk' : (desk.isEmpty ? 'Shared Desk' : '${desk.first['name']}');
            return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
              leading: CircleAvatar(child: Icon(_iconFor('${doc['category']}'))),
              title: Text('${doc['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text([workspace, '${doc['category']}', _visibility('${doc['visibility']}'), if (doc['expires_at'] != null) 'Expires ${_date(doc['expires_at'])}'].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openManager,
            ));
          }),
        ]);
      }),
    ],
  );

  String _visibility(String v) => v == 'desk' ? 'Desk members' : v == 'custom' ? 'Selected people' : 'Private';
  String _date(dynamic value) { final d = DateTime.tryParse('${value ?? ''}'); if (d == null) return ''; return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}'; }
  IconData _iconFor(String c) { switch (c) { case 'id': return Icons.badge_outlined; case 'certificate': return Icons.workspace_premium_outlined; case 'property': return Icons.home_work_outlined; case 'medical': return Icons.medical_information_outlined; case 'receipt': return Icons.receipt_outlined; default: return Icons.description_outlined; } }
}
