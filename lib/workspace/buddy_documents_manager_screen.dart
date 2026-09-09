import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/workspace_service.dart';

class BuddyDocumentsManagerScreen extends StatefulWidget {
  const BuddyDocumentsManagerScreen({super.key});
  @override State<BuddyDocumentsManagerScreen> createState() => _BuddyDocumentsManagerScreenState();
}

class _BuddyDocumentsManagerScreenState extends State<BuddyDocumentsManagerScreen> {
  final _service = WorkspaceService();
  late Future<List<Map<String,dynamic>>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = _service.documents();
  void _refresh() => setState(_reload);

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;
    final file = picked.files.single;
    if (file.size > WorkspaceService.maxDocumentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files must be 15 MB or smaller.')));
      return;
    }
    final results = await Future.wait([_service.desks(), _service.buddies()]);
    if (!mounted) return;
    final desks = List<Map<String,dynamic>>.from(results[0]).where((d) => d['role'] != 'viewer').toList();
    final buddies = List<Map<String,dynamic>>.from(results[1]);
    final title = TextEditingController(text: file.name);
    String category = 'other';
    String visibility = 'private';
    String? deskId;
    DateTime? expiresAt;
    final selected = <String>{};

    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Upload document'),
      content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: const ['id','certificate','property','medical','receipt','other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setLocal(() => category = v ?? 'other')),
        const SizedBox(height: 10),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text(expiresAt == null ? 'No expiry date' : 'Expires ${_date(expiresAt!)}'), trailing: const Icon(Icons.chevron_right), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 365))); if (d != null) setLocal(() => expiresAt = d); }),
        const SizedBox(height: 10),
        const Text('Who should be able to access this?', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'private', icon: Icon(Icons.lock_outline), label: Text('Only me')),
          ButtonSegment(value: 'desk', icon: Icon(Icons.groups_outlined), label: Text('Whole desk')),
          ButtonSegment(value: 'custom', icon: Icon(Icons.people_outline), label: Text('Selected people')),
        ], selected: {visibility}, onSelectionChanged: (v) => setLocal(() { visibility = v.first; selected.clear(); if (visibility != 'desk') deskId = null; })),
        if (visibility == 'desk') ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: deskId, decoration: const InputDecoration(labelText: 'Shared Desk'), items: desks.map((d) => DropdownMenuItem<String>(value: '${d['id']}', child: Text('${d['name']}'))).toList(), onChanged: (v) => setLocal(() => deskId = v)),
          if (desks.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('You do not have a writable Shared Desk.')),
        ],
        if (visibility == 'custom') ...[
          const SizedBox(height: 14),
          const Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Selected people only includes your myDesk Buddies. Shared Desk membership does not add someone to this list.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (buddies.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No Buddies yet. Add someone as a Buddy first to share directly.'))),
          ...buddies.map((b) { final id = '${b['user_id']}'; return CheckboxListTile(contentPadding: EdgeInsets.zero, value: selected.contains(id), secondary: _Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString()), title: Text('${b['full_name']}'), subtitle: const Text('Buddy'), onChanged: (checked) => setLocal(() => checked == true ? selected.add(id) : selected.remove(id))); }),
        ],
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (title.text.trim().isEmpty) return; if (visibility == 'desk' && deskId == null) return; if (visibility == 'custom' && selected.isEmpty) return; Navigator.pop(context, true); }, child: const Text('Upload'))],
    )));

    if (ok == true) {
      try {
        await _service.uploadDocument(title: title.text, category: category, fileName: file.name, bytes: file.bytes!, deskId: visibility == 'desk' ? deskId : null, visibility: visibility, recipientIds: selected.toList(), expiresAt: expiresAt);
        _refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded.')));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'))); }
    }
    title.dispose();
  }

  Future<void> _manage(Map<String,dynamic> doc) async {
    final results = await Future.wait([_service.desks(), _service.buddies(), _service.documentRecipientIds('${doc['id']}')]);
    if (!mounted) return;
    final desks = List<Map<String,dynamic>>.from(results[0]).where((d) => d['role'] != 'viewer').toList();
    final buddies = List<Map<String,dynamic>>.from(results[1]);
    String visibility = '${doc['visibility']}';
    String? deskId = doc['desk_id']?.toString();
    final selected = Set<String>.from(List<String>.from(results[2]));
    final buddyIds = buddies.map((b) => '${b['user_id']}').toSet();
    selected.removeWhere((id) => !buddyIds.contains(id));

    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Manage access'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'private', label: Text('Only me')), ButtonSegment(value: 'desk', label: Text('Whole desk')), ButtonSegment(value: 'custom', label: Text('Selected people'))], selected: {visibility}, onSelectionChanged: (v) => setLocal(() { visibility = v.first; selected.clear(); if (visibility != 'desk') deskId = null; })),
        if (visibility == 'desk') ...[const SizedBox(height: 14), DropdownButtonFormField<String>(initialValue: deskId, decoration: const InputDecoration(labelText: 'Shared Desk'), items: desks.map((d) => DropdownMenuItem<String>(value: '${d['id']}', child: Text('${d['name']}'))).toList(), onChanged: (v) => setLocal(() => deskId = v))],
        if (visibility == 'custom') ...[
          const SizedBox(height: 14),
          const Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Direct sharing is Buddy-only.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ...buddies.map((b) { final id = '${b['user_id']}'; return CheckboxListTile(contentPadding: EdgeInsets.zero, value: selected.contains(id), secondary: _Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString()), title: Text('${b['full_name']}'), onChanged: (checked) => setLocal(() => checked == true ? selected.add(id) : selected.remove(id))); }),
        ],
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (visibility == 'desk' && deskId == null) return; if (visibility == 'custom' && selected.isEmpty) return; Navigator.pop(context, true); }, child: const Text('Save'))],
    )));

    if (ok == true) {
      try {
        await _service.updateDocumentAccess(documentId: '${doc['id']}', visibility: visibility, deskId: visibility == 'desk' ? deskId : null, recipientIds: selected.toList());
        _refresh();
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update access: $e'))); }
    }
  }

  Future<void> _open(Map<String,dynamic> doc) async {
    try { final url = await _service.documentUrl('${doc['storage_path']}'); await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Upload & manage documents', style: TextStyle(fontWeight: FontWeight.w900))),
    floatingActionButton: FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
    body: FutureBuilder<List<Map<String,dynamic>>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Could not load documents: ${snap.error}'));
      final docs = snap.data ?? [];
      if (docs.isEmpty) return const Center(child: Text('No documents yet.'));
      return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: docs.map((doc) {
        final mine = doc['owner_id'] == _service.currentUserId;
        return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.description_outlined)), title: Text('${doc['title']}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${doc['category']} · ${_visibility('${doc['visibility']}')}'), onTap: () => _open(doc), trailing: mine ? IconButton(tooltip: 'Manage access', icon: const Icon(Icons.manage_accounts_outlined), onPressed: () => _manage(doc)) : const Icon(Icons.visibility_outlined)));
      }).toList());
    }),
  );

  String _visibility(String v) => v == 'desk' ? 'Whole desk' : v == 'custom' ? 'Selected Buddies' : 'Only me';
  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

class _Avatar extends StatelessWidget {
  final String name; final String? url;
  const _Avatar({required this.name, this.url});
  @override Widget build(BuildContext context) { if (url != null && url!.isNotEmpty) return CircleAvatar(backgroundImage: NetworkImage(url!)); return CircleAvatar(child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase())); }
}
