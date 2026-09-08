import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.documents();
  }

  void _refresh() => setState(() => _future = _service.documents());

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;

    final desks = await _service.desks();
    if (!mounted) return;

    final title = TextEditingController(text: picked.files.single.name);
    String category = 'other';
    String visibility = 'private';
    String? deskId;
    List<Map<String, dynamic>> members = [];
    final selected = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> loadMembers(String? id) async {
            if (id == null) {
              setLocal(() {
                members = [];
                selected.clear();
              });
              return;
            }
            final rows = await _service.deskMembers(id);
            setLocal(() {
              members = rows;
              selected.removeWhere((id) => !rows.any((m) => m['user_id'] == id));
            });
          }

          return AlertDialog(
            title: const Text('Upload document'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const ['id', 'certificate', 'property', 'medical', 'receipt', 'other']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setLocal(() => category = v ?? 'other'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Who should be able to access this?', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'private', icon: Icon(Icons.lock_outline), label: Text('Only me')),
                        ButtonSegment(value: 'desk', icon: Icon(Icons.groups_outlined), label: Text('Whole desk')),
                        ButtonSegment(value: 'custom', icon: Icon(Icons.person_add_alt), label: Text('Selected people')),
                      ],
                      selected: {visibility},
                      onSelectionChanged: (values) => setLocal(() {
                        visibility = values.first;
                        if (visibility == 'private') {
                          deskId = null;
                          members = [];
                          selected.clear();
                        }
                      }),
                    ),
                    if (visibility != 'private') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: deskId,
                        decoration: const InputDecoration(labelText: 'Shared Desk'),
                        items: desks
                            .map((d) => DropdownMenuItem<String>(
                                  value: d['id'] as String,
                                  child: Text('${d['name']}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setLocal(() {
                            deskId = v;
                            selected.clear();
                          });
                          loadMembers(v);
                        },
                      ),
                    ],
                    if (visibility == 'custom' && deskId != null) ...[
                      const SizedBox(height: 14),
                      const Text('Choose people', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (members.isEmpty)
                        const Text('No other members found in this desk.', style: TextStyle(color: Colors.black54)),
                      ...members.where((m) => m['is_me'] != true).map((member) {
                        final id = member['user_id'] as String;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(id),
                          title: Text('${member['full_name']}'),
                          subtitle: Text('${member['role']}'),
                          onChanged: (checked) => setLocal(() {
                            if (checked == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      }),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      visibility == 'private'
                          ? 'Only you will see this document.'
                          : visibility == 'desk'
                              ? 'Every current member of the selected desk will be able to view it.'
                              : 'Only the people you select will be able to view it.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  if (visibility != 'private' && deskId == null) return;
                  if (visibility == 'custom' && selected.isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) {
      title.dispose();
      return;
    }

    try {
      await _service.uploadDocument(
        title: title.text.trim(),
        category: category,
        fileName: picked.files.single.name,
        bytes: picked.files.single.bytes!,
        deskId: deskId,
        visibility: visibility,
        recipientIds: selected.toList(),
      );
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      title.dispose();
    }
  }

  Future<void> _manageAccess(Map<String, dynamic> document) async {
    final desks = await _service.desks();
    if (!mounted) return;

    String visibility = '${document['visibility']}';
    String? deskId = document['desk_id'] as String?;
    List<Map<String, dynamic>> members = deskId == null ? [] : await _service.deskMembers(deskId);
    final selected = <String>{};
    if (visibility == 'custom') {
      selected.addAll(await _service.documentRecipientIds(document['id'] as String));
    }
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> loadMembers(String? id) async {
            if (id == null) {
              setLocal(() {
                members = [];
                selected.clear();
              });
              return;
            }
            final rows = await _service.deskMembers(id);
            setLocal(() {
              members = rows;
              selected.removeWhere((uid) => !rows.any((m) => m['user_id'] == uid));
            });
          }

          return AlertDialog(
            title: const Text('Manage access'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'private', label: Text('Only me')),
                        ButtonSegment(value: 'desk', label: Text('Whole desk')),
                        ButtonSegment(value: 'custom', label: Text('Selected people')),
                      ],
                      selected: {visibility},
                      onSelectionChanged: (values) => setLocal(() {
                        visibility = values.first;
                        if (visibility == 'private') {
                          deskId = null;
                          members = [];
                          selected.clear();
                        }
                      }),
                    ),
                    if (visibility != 'private') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: deskId,
                        decoration: const InputDecoration(labelText: 'Shared Desk'),
                        items: desks
                            .map((d) => DropdownMenuItem<String>(value: d['id'] as String, child: Text('${d['name']}')))
                            .toList(),
                        onChanged: (v) {
                          setLocal(() => deskId = v);
                          loadMembers(v);
                        },
                      ),
                    ],
                    if (visibility == 'custom' && deskId != null) ...[
                      const SizedBox(height: 12),
                      ...members.where((m) => m['is_me'] != true).map((member) {
                        final id = member['user_id'] as String;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(id),
                          title: Text('${member['full_name']}'),
                          subtitle: Text('${member['role']}'),
                          onChanged: (checked) => setLocal(() {
                            checked == true ? selected.add(id) : selected.remove(id);
                          }),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (visibility != 'private' && deskId == null) return;
                  if (visibility == 'custom' && selected.isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save access'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      try {
        await _service.updateDocumentAccess(
          documentId: document['id'] as String,
          visibility: visibility,
          deskId: deskId,
          recipientIds: selected.toList(),
        );
        _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update access: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documents & Vault', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Private by default. Share only with the people who need access.', style: TextStyle(color: Colors.black54)),
              ],
            ),
            FilledButton.icon(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('Upload document')),
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
              return _MessageCard(icon: Icons.cloud_off, title: 'Could not load documents', message: '${snapshot.error}');
            }
            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return const _MessageCard(icon: Icons.folder_open, title: 'Your vault is empty', message: 'Upload a document and decide exactly who can access it.');
            }
            return Card(
              child: Column(
                children: docs.map((doc) {
                  final visibility = '${doc['visibility']}';
                  final isOwner = doc['owner_id'] == _serviceUserId();
                  return ListTile(
                    leading: CircleAvatar(child: Icon(_iconFor('${doc['category']}'))),
                    title: Text('${doc['title']}'),
                    subtitle: Text('${doc['category']} · ${_visibilityLabel(visibility)}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Open',
                          onPressed: () async {
                            try {
                              final url = await _service.documentUrl('${doc['storage_path']}');
                              if (mounted) {
                                showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('${doc['title']}'),
                                    content: SelectableText(url),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                        ),
                        if (isOwner)
                          IconButton(tooltip: 'Manage access', onPressed: () => _manageAccess(doc), icon: const Icon(Icons.manage_accounts_outlined)),
                        if (isOwner)
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () async {
                              try {
                                await _service.deleteDocument(doc['id'] as String, '${doc['storage_path']}');
                                _refresh();
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  String? _serviceUserId() {
    try {
      return _service.currentUserId;
    } catch (_) {
      return null;
    }
  }

  String _visibilityLabel(String value) {
    switch (value) {
      case 'desk': return 'Everyone in desk';
      case 'custom': return 'Selected people';
      default: return 'Only me';
    }
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'id': return Icons.badge_outlined;
      case 'certificate': return Icons.workspace_premium_outlined;
      case 'property': return Icons.home_work_outlined;
      case 'medical': return Icons.medical_information_outlined;
      case 'receipt': return Icons.receipt_outlined;
      default: return Icons.description_outlined;
    }
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _MessageCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
