import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/workspace_service.dart';
import 'document_category_screen.dart';

class DocumentsHubScreen extends StatefulWidget {
  const DocumentsHubScreen({super.key});

  @override
  State<DocumentsHubScreen> createState() => _DocumentsHubScreenState();
}

class _DocumentsHubScreenState extends State<DocumentsHubScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;
  String _workspaceFilter = 'all';

  static const _categories = <String, _DocumentCategory>{
    'id': _DocumentCategory('IDs', Icons.badge_outlined, Color(0xFF2F80FF), Color(0xFF102A52)),
    'certificate': _DocumentCategory('Certificates', Icons.workspace_premium_outlined, Color(0xFF21C77A), Color(0xFF103326)),
    'property': _DocumentCategory('Property', Icons.home_work_outlined, Color(0xFF7B61FF), Color(0xFF241D52)),
    'medical': _DocumentCategory('Medical', Icons.medical_information_outlined, Color(0xFFFF4D6D), Color(0xFF401721)),
    'receipt': _DocumentCategory('Receipts', Icons.receipt_long_outlined, Color(0xFFFF8A2A), Color(0xFF44270F)),
    'other': _DocumentCategory('Others', Icons.folder_outlined, Color(0xFF8EA1B8), Color(0xFF202A36)),
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
    String category = 'other';
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
                  items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.label))).toList(),
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
                  if (desks.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('You do not have a writable Shared Desk.')),
                ],
                if (visibility == 'custom') ...[
                  const SizedBox(height: 14),
                  const Text('Choose Buddies', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Selected people only includes your myDesk Buddies.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  if (buddies.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No Buddies yet. Add someone as a Buddy first.'))),
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

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<Map<String, dynamic>> _workspaceDocs(List<Map<String, dynamic>> docs) => docs.where((d) {
        if (_workspaceFilter == 'all') return true;
        if (_workspaceFilter == 'personal') return d['desk_id'] == null;
        return '${d['desk_id']}' == _workspaceFilter;
      }).toList();

  Future<void> _openCategory({
    required String key,
    required _DocumentCategory category,
    required String workspaceLabel,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCategoryScreen(
          categoryKey: key,
          categoryLabel: category.label,
          categoryIcon: category.icon,
          foreground: category.foreground,
          background: category.background,
          workspaceFilter: _workspaceFilter,
          workspaceLabel: workspaceLabel,
        ),
      ),
    );
    _refresh();
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
                Text('Choose a space, then open a category to see its documents.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                'personal': 'Personal',
                for (final d in desks) '${d['id']}': '${d['name']}',
              };
              if (!workspaceFilters.containsKey(_workspaceFilter)) _workspaceFilter = 'all';

              final inWorkspace = _workspaceDocs(docs);
              final workspaceLabel = workspaceFilters[_workspaceFilter] ?? 'All';
              int countFor(String category) => inWorkspace.where((d) => '${d['category']}' == category).length;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 10,
                    children: workspaceFilters.entries
                        .map((e) => ChoiceChip(
                              label: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Text(e.value)),
                              selected: _workspaceFilter == e.key,
                              onSelected: (_) => setState(() => _workspaceFilter = e.key),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 2 : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: columns == 2 ? 2.55 : 4.0,
                      children: _categories.entries.map((entry) {
                        final category = entry.value;
                        final count = countFor(entry.key);
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openCategory(key: entry.key, category: category, workspaceLabel: workspaceLabel),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(color: category.background, borderRadius: BorderRadius.circular(16)),
                                  child: Icon(category.icon, color: category.foreground, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(category.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text('$count ${count == 1 ? 'document' : 'documents'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ]);
            },
          ),
        ],
      );

  static String _date(dynamic value) {
    final d = value is DateTime ? value : DateTime.tryParse('${value ?? ''}');
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _DocumentCategory {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _DocumentCategory(this.label, this.icon, this.foreground, this.background);
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
