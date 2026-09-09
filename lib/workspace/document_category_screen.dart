import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'document_preview_screen.dart';

class DocumentCategoryScreen extends StatefulWidget {
  final String categoryKey;
  final String categoryLabel;
  final IconData categoryIcon;
  final Color foreground;
  final Color background;
  final String workspaceFilter;
  final String workspaceLabel;

  const DocumentCategoryScreen({
    super.key,
    required this.categoryKey,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.foreground,
    required this.background,
    required this.workspaceFilter,
    required this.workspaceLabel,
  });

  @override
  State<DocumentCategoryScreen> createState() => _DocumentCategoryScreenState();
}

class _DocumentCategoryScreenState extends State<DocumentCategoryScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = Future.wait([_service.documents(), _service.desks()]);
  void _refresh() => setState(_reload);

  bool _inWorkspace(Map<String, dynamic> doc) {
    if (widget.workspaceFilter == 'all') return true;
    if (widget.workspaceFilter == 'personal') return doc['desk_id'] == null;
    return '${doc['desk_id']}' == widget.workspaceFilter;
  }

  Future<void> _open(Map<String, dynamic> doc) async {
    try {
      final path = '${doc['storage_path']}';
      final url = await _service.documentUrl(path);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(title: '${doc['title']}', url: url, storagePath: path),
        ),
      );
    } catch (e) {
      _message('Could not open file: $e');
    }
  }

  Future<void> _manageAccess(Map<String, dynamic> doc) async {
    final results = await Future.wait([
      _service.desks(),
      _service.buddies(),
      _service.documentRecipientIds('${doc['id']}'),
    ]);
    if (!mounted) return;

    final desks = List<Map<String, dynamic>>.from(results[0]).where((d) => d['role'] != 'viewer').toList();
    final buddies = List<Map<String, dynamic>>.from(results[1]);
    String visibility = '${doc['visibility']}';
    String? deskId = doc['desk_id']?.toString();
    final selected = Set<String>.from(List<String>.from(results[2]));
    final buddyIds = buddies.map((b) => '${b['user_id']}').toSet();
    selected.removeWhere((id) => !buddyIds.contains(id));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Manage access · ${doc['title']}'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'private', label: Text('Only me')),
                    ButtonSegment(value: 'desk', label: Text('Whole desk')),
                    ButtonSegment(value: 'custom', label: Text('Selected people')),
                  ],
                  selected: {visibility},
                  onSelectionChanged: (value) => setLocal(() {
                    visibility = value.first;
                    selected.clear();
                    if (visibility != 'desk') deskId = null;
                  }),
                ),
                if (visibility == 'desk') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: deskId,
                    decoration: const InputDecoration(labelText: 'Shared Desk'),
                    items: desks.map((d) => DropdownMenuItem(value: '${d['id']}', child: Text('${d['name']}'))).toList(),
                    onChanged: (value) => setLocal(() => deskId = value),
                  ),
                ],
                if (visibility == 'custom') ...[
                  const SizedBox(height: 14),
                  const Align(alignment: Alignment.centerLeft, child: Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(height: 6),
                  ...buddies.map((b) {
                    final id = '${b['user_id']}';
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(id),
                      title: Text('${b['full_name']}'),
                      subtitle: const Text('Buddy'),
                      secondary: _Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString()),
                      onChanged: (checked) => setLocal(() => checked == true ? selected.add(id) : selected.remove(id)),
                    );
                  }),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (visibility == 'desk' && deskId == null) return;
                if (visibility == 'custom' && selected.isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save access'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _service.updateDocumentAccess(
          documentId: '${doc['id']}',
          visibility: visibility,
          deskId: visibility == 'desk' ? deskId : null,
          recipientIds: selected.toList(),
        );
        _refresh();
        _message('Access updated.');
      } catch (e) {
        _message('Could not update access: $e');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete document?'),
            content: Text('“${doc['title']}” will be permanently removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!ok) return;
    try {
      await _service.deleteDocument('${doc['id']}', '${doc['storage_path']}');
      _refresh();
      _message('Document deleted.');
    } catch (e) {
      _message('Could not delete document: $e');
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load documents: ${snapshot.error}'));
          }

          final docs = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
          final desks = List<Map<String, dynamic>>.from(snapshot.data![1] as List);
          final items = docs.where((d) => _inWorkspace(d) && '${d['category']}' == widget.categoryKey).toList();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: widget.background, borderRadius: BorderRadius.circular(17)),
                      child: Icon(widget.categoryIcon, color: widget.foreground, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.categoryLabel, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${widget.workspaceLabel} · ${items.length} ${items.length == 1 ? 'document' : 'documents'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(34), child: Center(child: Text('No documents in this section yet.')))),
              ...items.map((doc) {
                final desk = desks.where((d) => '${d['id']}' == '${doc['desk_id']}').toList();
                final workspace = doc['desk_id'] == null ? 'Personal' : (desk.isEmpty ? 'Shared Desk' : '${desk.first['name']}');
                final mine = doc['owner_id'] == _service.currentUserId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: widget.background, borderRadius: BorderRadius.circular(13)),
                      child: Icon(widget.categoryIcon, color: widget.foreground),
                    ),
                    title: Text('${doc['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      workspace,
                      _visibility('${doc['visibility']}'),
                      if (doc['expires_at'] != null) 'Expires ${_date(doc['expires_at'])}',
                    ].join(' · ')),
                    onTap: () => _open(doc),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'open') await _open(doc);
                        if (value == 'access') await _manageAccess(doc);
                        if (value == 'delete') await _delete(doc);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'open', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.visibility_outlined), title: Text('Preview'))),
                        if (mine) const PopupMenuItem(value: 'access', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.manage_accounts_outlined), title: Text('Manage access'))),
                        if (mine) const PopupMenuDivider(),
                        if (mine) const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _visibility(String value) => value == 'desk' ? 'Desk members' : value == 'custom' ? 'Selected Buddies' : 'Private';

  String _date(dynamic value) {
    final d = DateTime.tryParse('${value ?? ''}');
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) return CircleAvatar(backgroundImage: NetworkImage(url!));
    return CircleAvatar(child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()));
  }
}
