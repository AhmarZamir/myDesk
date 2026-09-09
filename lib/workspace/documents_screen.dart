import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete document?'),
            content: Text('“$title” and its stored file will be permanently removed. This cannot be undone.'),
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
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;
    final file = picked.files.single;
    if (file.size > WorkspaceService.maxDocumentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files must be 15 MB or smaller.')));
      return;
    }

    final allDesks = await _service.desks();
    final desks = allDesks.where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;

    final title = TextEditingController(text: file.name);
    String category = 'other';
    String visibility = 'private';
    String? deskId;
    DateTime? expiresAt;
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
              width: 540,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const ['id', 'certificate', 'property', 'medical', 'receipt', 'other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setLocal(() => category = v ?? 'other'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(expiresAt == null ? 'No expiry date' : 'Expires ${_date(expiresAt!)}'),
                    subtitle: const Text('Optional · myDesk will surface upcoming expiries on Home.'),
                    trailing: expiresAt == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(onPressed: () => setLocal(() => expiresAt = null), icon: const Icon(Icons.close)),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) setLocal(() => expiresAt = pickedDate);
                    },
                  ),
                  const SizedBox(height: 10),
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
                      key: ValueKey('upload-desk-$deskId'),
                      initialValue: deskId,
                      decoration: const InputDecoration(labelText: 'Shared Desk'),
                      items: desks.map((d) => DropdownMenuItem<String>(value: d['id'] as String, child: Text('${d['name']}'))).toList(),
                      onChanged: (v) {
                        setLocal(() {
                          deskId = v;
                          selected.clear();
                        });
                        loadMembers(v);
                      },
                    ),
                    if (desks.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('You do not currently have a writable Shared Desk.'),
                    ],
                  ],
                  if (visibility == 'custom' && deskId != null) ...[
                    const SizedBox(height: 14),
                    const Text('Choose people', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (members.where((m) => m['is_me'] != true).isEmpty) const Text('No other members found in this desk.'),
                    ...members.where((m) => m['is_me'] != true).map((member) {
                      final id = member['user_id'] as String;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(id),
                        title: Text('${member['full_name']}'),
                        subtitle: Text('${member['role']}'),
                        onChanged: (checked) => setLocal(() => checked == true ? selected.add(id) : selected.remove(id)),
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
                  ),
                ]),
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
        title: title.text,
        category: category,
        fileName: file.name,
        bytes: file.bytes!,
        deskId: deskId,
        visibility: visibility,
        recipientIds: selected.toList(),
        expiresAt: expiresAt,
      );
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      title.dispose();
    }
  }

  Future<void> _manageAccess(Map<String, dynamic> document) async {
    final allDesks = await _service.desks();
    final desks = allDesks.where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;

    String visibility = '${document['visibility']}';
    String? deskId = document['desk_id'] as String?;
    List<Map<String, dynamic>> members = deskId == null ? [] : await _service.deskMembers(deskId);
    final selected = <String>{};
    if (visibility == 'custom') selected.addAll(await _service.documentRecipientIds(document['id'] as String));
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
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      key: ValueKey('manage-desk-$deskId'),
                      initialValue: deskId,
                      decoration: const InputDecoration(labelText: 'Shared Desk'),
                      items: desks.map((d) => DropdownMenuItem<String>(value: d['id'] as String, child: Text('${d['name']}'))).toList(),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Access updated.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update access: $e')));
      }
    }
  }

  Future<void> _previewDocument(Map<String, dynamic> document) async {
    try {
      final url = await _service.documentUrl('${document['storage_path']}');
      if (!mounted) return;
      final fileName = '${document['storage_path']}'.split('/').last.toLowerCase();
      final isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any(fileName.endsWith);

      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      '${document['title']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 12),
                Flexible(
                  child: isImage
                      ? Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Center(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                                errorBuilder: (_, __, ___) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.broken_image_outlined, size: 48),
                                  SizedBox(height: 8),
                                  Text('Could not render this image.'),
                                ])),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.insert_drive_file_outlined, size: 62),
                            const SizedBox(height: 14),
                            const Text('Preview is not available for this file type.', textAlign: TextAlign.center),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(url);
                                if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file.')));
                                }
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open file'),
                            ),
                          ]),
                        ),
                ),
              ]),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
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
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Documents & Vault', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Private by default. Share only with the people who need access.'),
            ]),
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
              return _MessageCard(icon: Icons.cloud_off, title: 'Could not load documents', message: '${snapshot.error}', onRetry: _refresh);
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
                  final expiry = DateTime.tryParse('${doc['expires_at'] ?? ''}');
                  return ListTile(
                    leading: CircleAvatar(child: Icon(_iconFor('${doc['category']}'))),
                    title: Text('${doc['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      '${doc['category']}',
                      _visibilityLabel(visibility),
                      if (expiry != null) 'Expires ${_date(expiry)}',
                    ].join(' · ')),
                    onTap: () => _previewDocument(doc),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(tooltip: 'Preview', onPressed: () => _previewDocument(doc), icon: const Icon(Icons.visibility_outlined)),
                      if (isOwner)
                        IconButton(tooltip: 'Manage access', onPressed: () => _manageAccess(doc), icon: const Icon(Icons.manage_accounts_outlined)),
                      if (isOwner)
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () async {
                            if (!await _confirmDelete('${doc['title']}')) return;
                            try {
                              await _service.deleteDocument(doc['id'] as String, '${doc['storage_path']}');
                              _refresh();
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ]),
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

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const _MessageCard({required this.icon, required this.title, required this.message, this.onRetry});

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
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ]),
      ),
    );
  }
}
