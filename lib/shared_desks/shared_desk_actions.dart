import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class SharedDeskActions {
  static Future<bool> uploadDocument(
    BuildContext context, {
    required WorkspaceService service,
    required String deskId,
  }) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !context.mounted) return false;
    final file = picked.files.single;
    if (file.size > WorkspaceService.maxDocumentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Files must be 15 MB or smaller.')));
      return false;
    }

    final title = TextEditingController(text: file.name);
    String category = 'other';
    DateTime? expiresAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Share document in this Desk'),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const ['id','certificate','property','medical','receipt','other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setLocal(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(expiresAt == null ? 'No expiry date' : 'Expires ${_date(expiresAt!)}'),
                trailing: expiresAt == null ? const Icon(Icons.chevron_right) : IconButton(onPressed: () => setLocal(() => expiresAt = null), icon: const Icon(Icons.close)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: dialogContext,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setLocal(() => expiresAt = date);
                },
              ),
              const SizedBox(height: 8),
              const Row(children: [Icon(Icons.groups_outlined, size: 18), SizedBox(width: 8), Expanded(child: Text('This file will be visible to all current members of this Shared Desk.'))]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () { if (title.text.trim().isNotEmpty) Navigator.pop(dialogContext, true); }, child: const Text('Upload')),
          ],
        ),
      ),
    );

    if (ok != true) { title.dispose(); return false; }
    try {
      await service.uploadDocument(
        title: title.text,
        category: category,
        fileName: file.name,
        bytes: file.bytes!,
        deskId: deskId,
        visibility: 'desk',
        expiresAt: expiresAt,
      );
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document shared in this Desk.')));
      return true;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not upload document: $e')));
      return false;
    } finally {
      title.dispose();
    }
  }

  static Future<bool> addTask(
    BuildContext context, {
    required WorkspaceService service,
    required String deskId,
  }) async {
    final members = await service.deskMembers(deskId);
    if (!context.mounted) return false;
    final title = TextEditingController();
    final description = TextEditingController();
    String priority = 'medium';
    String? assigneeId;
    DateTime? due;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Assign task in this Desk'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')),
                const SizedBox(height: 12),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['low','medium','high'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: assigneeId,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: members.map((m) => DropdownMenuItem<String>(value: '${m['user_id']}', child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'))).toList(),
                  onChanged: (v) => setLocal(() => assigneeId = v),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month),
                  title: Text(due == null ? 'No due date' : 'Due ${_date(due!)}'),
                  onTap: () async {
                    final date = await showDatePicker(context: dialogContext, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now());
                    if (date != null) setLocal(() => due = date);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () { if (title.text.trim().isNotEmpty && assigneeId != null) Navigator.pop(dialogContext, true); }, child: const Text('Assign task')),
          ],
        ),
      ),
    );

    if (ok != true) { title.dispose(); description.dispose(); return false; }
    try {
      await service.addTask(title: title.text, description: description.text, priority: priority, deskId: deskId, assigneeId: assigneeId, dueDate: due);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added to this Desk.')));
      return true;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add task: $e')));
      return false;
    } finally {
      title.dispose(); description.dispose();
    }
  }

  static Future<bool> addBill(
    BuildContext context, {
    required WorkspaceService service,
    required String deskId,
  }) async {
    final members = await service.deskMembers(deskId);
    if (!context.mounted) return false;
    final title = TextEditingController();
    final amount = TextEditingController();
    String? assignedTo;
    DateTime? due;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Add bill in this Desk'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Bill name')),
              const SizedBox(height: 12),
              TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. ')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: assignedTo,
                decoration: const InputDecoration(labelText: 'Responsible person'),
                items: members.map((m) => DropdownMenuItem<String>(value: '${m['user_id']}', child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'))).toList(),
                onChanged: (v) => setLocal(() => assignedTo = v),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: Text(due == null ? 'No due date' : 'Due ${_date(due!)}'),
                onTap: () async {
                  final date = await showDatePicker(context: dialogContext, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now());
                  if (date != null) setLocal(() => due = date);
                },
              ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () { final value = double.tryParse(amount.text.trim()); if (title.text.trim().isNotEmpty && value != null && value > 0 && assignedTo != null) Navigator.pop(dialogContext, true); }, child: const Text('Add bill')),
          ],
        ),
      ),
    );

    final value = double.tryParse(amount.text.trim());
    if (ok != true || value == null) { title.dispose(); amount.dispose(); return false; }
    try {
      await service.addBill(title: title.text, amount: value, dueDate: due, deskId: deskId, assignedTo: assignedTo);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill added to this Desk.')));
      return true;
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add bill: $e')));
      return false;
    } finally {
      title.dispose(); amount.dispose();
    }
  }

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
