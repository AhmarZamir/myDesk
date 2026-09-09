import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'document_preview_screen.dart';

class DocumentsHubScreen extends StatefulWidget {
  const DocumentsHubScreen({super.key});

  @override
  State<DocumentsHubScreen> createState() => _DocumentsHubScreenState();
}

class _DocumentsHubScreenState extends State<DocumentsHubScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;
  String _workspaceFilter = 'all';
  String _categoryFilter = 'all';

  static const _categories = <String, (String, IconData)>{
    'all': ('All categories', Icons.apps_rounded),
    'id': ('IDs', Icons.badge_outlined),
    'certificate': ('Certificates', Icons.workspace_premium_outlined),
    'property': ('Property', Icons.home_work_outlined),
    'medical': ('Medical', Icons.medical_information_outlined),
    'receipt': ('Receipts', Icons.receipt_outlined),
    'other': ('Other', Icons.description_outlined),
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = Future.wait([_service.documents(), _service.desks()]);
  void _refresh() => setState(_reload);

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;
    final file = picked.files.single;
    if (file.size > WorkspaceService.maxDocumentBytes) {
      _message('Files must be 15 MB or smaller.');
      return;
    }

    final results = await Future.wait([_service.desks(), _service.buddies()]);
    if (!mounted) return;
    final desks = List<Map<String, dynamic>>.from(results[0]).where((d) => d['role'] != 'viewer').toList();
    final buddies = List<Map<String, dynamic>>.from(results[1]);
    final title = TextEditingController(text: file.name);
    String category = _categoryFilter == 'all' ? 'other' : _categoryFilter;
    String visibility = 'private';
    String? deskId;
    DateTime? expiresAt;
    final selected = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Upload document'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.entries
                      .where((e) => e.key != 'all')
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1)))
                      .toList(),
                  onChanged: (v) => setLocal(() => category = v ?? 'other'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(expiresAt == null ? 'No expiry date' : 'Expires ${_date(expiresAt)}'),
                  trailing: expiresAt == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(onPressed: () => setLocal(() => expiresAt = null), icon: const Icon(Icons.close)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setLocal(() => expiresAt = d);
                  },
                ),
                const SizedBox(height: 10),
                const Text('Who should be able to access this?', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'private', icon: Icon(Icons.lock_outline), label: Text('Only me')),
                    ButtonSegment(value: 'desk', icon: Icon(Icons.groups_outlined), label: Text('Whole desk')),
                    ButtonSegment(value: 'custom', icon: Icon(Icons.people_outline), label: Text('Selected people')),
                  ],
                  selected: {visibility},
                  onSelectionChanged: (v) => setLocal(() {
                    visibility = v.first;
                    selected.clear();
                    if (visibility != 'desk') deskId = null;
                  }),
                ),
                if (visibility == 'desk') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: deskId,
                    decoration: const InputDecoration(labelText: 'Shared Desk'),
                    items: desks.map((d) => DropdownMenuItem<String>(value: '${d['id']}', child: Text('${d['name']}'))).toList(),
                    onChanged: (v) => setLocal(() => deskId = v),
                  ),
                  if (desks.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('You do not have a writable Shared Desk.')),
                ],
                if (visibility == 'custom') ...[
                  const SizedBox(height: 14),
                  const Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Selected people only includes your myDesk Buddies.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (buddies.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No Buddies yet. Add someone as a Buddy first.'))),
                  ...buddies.map((b) {
                    final id = '${b['user_id']}';
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(id),
                      secondary: _Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString()),
                      title: Text('${b['full_name']}'),
                      subtitle: const Text('Buddy'),
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
                if (title.text.trim().isEmpty) return;
                if (visibility == 'desk' && deskId == null) return;
                if (visibility == 'custom' && selected.isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _service.uploadDocument(
          title: title.text,
          category: category,
          fileName: file.name,
          bytes: file.bytes!,
          deskId: visibility == 'desk' ? deskId : null,
          visibility: visibility,
          recipientIds: selected.toList(),
          expiresAt: expiresAt,
        );
        _refresh();
        _message('Document uploaded.');
      } catch (e) {
        _message('Upload failed: $e');
      }
    }
    title.dispose();
  }

  Future<void> _manageAccess(Map<String, dynamic> doc) async {
    final results = await Future.wait([_service.desks(), _service.buddies(), _service.documentRecipientIds('${doc['id']}')]);
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
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'private', label: Text('Only me')),
                    ButtonSegment(value: 'desk', label: Text('Whole desk')),
                    ButtonSegment(value: 'custom', label: Text('Selected people')),
                  ],
                  selected: {visibility},
                  onSelectionChanged: (v) => setLocal(() {
                    visibility = v.first;
                    selected.clear();
                    if (visibility != 'desk') deskId = null;
                  }),
                ),
                if (visibility == 'desk') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: deskId,
                    decoration: const InputDecoration(labelText: 'Shared Desk'),
                    items: desks.map((d) => DropdownMenuItem<String>(value: '${d['id']}', child: Text('${d['name']}'))).toList(),
                    onChanged: (v) => setLocal(() => deskId = v),
                  ),
                ],
                if (visibility == 'custom') ...[
                  const SizedBox(height: 14),
                  const Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ...buddies.map((b) {
                    final id = '${b['user_id']}';
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(id),
                      secondary: _Avatar(name: '${b['full_name']}', url: b['avatar_url']?.toString()),
                      title: Text('${b['full_name']}'),
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

  Future<void> _open(Map<String, dynamic> doc) async {
    try {
      final path = '${doc['storage_path']}';
      final url = await _service.documentUrl(path);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPreviewScreen(
            title: '${doc['title']}',
            url: url,
            storagePath: path,
          ),
        ),
      );
    } catch (e) {
      _message('Could not open file: $e');
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
        ) ??
        false;
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

  List<Map<String, dynamic>> _workspaceDocs(List<Map<String, dynamic>> docs) {
    return docs.where((d) {
      if (_workspaceFilter == 'all') return true;
      if (_workspaceFilter == 'personal') return d['desk_id'] == null;
      return '${d['desk_id']}' == _workspaceFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Documents & Vault', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('Browse by workspace and category, then preview and manage files right here.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              FilledButton.icon(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('Upload document')),
            ],
          ),
          const SizedBox(height: 22),
          FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load documents: ${snap.error}')));
              }

              final docs = List<Map<String, dynamic>>.from(snap.data![0] as List);
              final desks = List<Map<String, dynamic>>.from(snap.data![1] as List);
              final workspaceFilters = <String, String>{
                'all': 'All',
                'personal': 'My Desk',
                for (final d in desks) '${d['id']}': '${d['name']}',
              };
              if (!workspaceFilters.containsKey(_workspaceFilter)) _workspaceFilter = 'all';

              final inWorkspace = _workspaceDocs(docs);
              final visible = inWorkspace.where((d) => _categoryFilter == 'all' || '${d['category']}' == _categoryFilter).toList();

              int countFor(String category) => category == 'all'
                  ? inWorkspace.length
                  : inWorkspace.where((d) => '${d['category']}' == category).length;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Spaces', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    children: workspaceFilters.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _workspaceFilter == e.key,
                              onSelected: (_) => setState(() => _workspaceFilter = e.key),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Categories', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1050 ? 4 : width >= 700 ? 3 : width >= 430 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: columns == 1 ? 4.1 : 2.25,
                    children: _categories.entries.map((e) {
                      final selected = _categoryFilter == e.key;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => setState(() => _categoryFilter = e.key),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer,
                                foregroundColor: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
                                child: Icon(e.value.$2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(e.value.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('${countFor(e.key)} files', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                            ]),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Text(_categories[_categoryFilter]!.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  Text('${visible.length} ${visible.length == 1 ? 'file' : 'files'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(34), child: Center(child: Text('No documents in this category and space.')))),
                ...visible.map((doc) {
                  final desk = desks.where((d) => '${d['id']}' == '${doc['desk_id']}').toList();
                  final workspace = doc['desk_id'] == null ? 'My Desk' : (desk.isEmpty ? 'Shared Desk' : '${desk.first['name']}');
                  final mine = doc['owner_id'] == _service.currentUserId;
                  final category = '${doc['category']}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(_categories[category]?.$2 ?? Icons.description_outlined)),
                      title: Text('${doc['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text([
                        workspace,
                        _categories[category]?.$1 ?? category,
                        _visibility('${doc['visibility']}'),
                        if (doc['expires_at'] != null) 'Expires ${_date(doc['expires_at'])}',
                      ].join(' · ')),
                      onTap: () => _open(doc),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Document actions',
                        onSelected: (value) async {
                          if (value == 'open') await _open(doc);
                          if (value == 'access') await _manageAccess(doc);
                          if (value == 'delete') await _delete(doc);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.visibility_outlined), title: Text('Preview'))),
                          if (mine)
                            const PopupMenuItem(value: 'access', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.manage_accounts_outlined), title: Text('Manage access'))),
                          if (mine) const PopupMenuDivider(),
                          if (mine)
                            const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                        ],
                      ),
                    ),
                  );
                }),
              ]);
            },
          ),
        ],
      );

  String _visibility(String v) => v == 'desk' ? 'Desk members' : v == 'custom' ? 'Selected Buddies' : 'Private';

  String _date(dynamic value) {
    final d = value is DateTime ? value : DateTime.tryParse('${value ?? ''}');
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
