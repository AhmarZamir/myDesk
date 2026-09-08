import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = service.documents();
  }

  void refresh() => setState(() => future = service.documents());

  Future<void> upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.single.bytes == null || !mounted) return;

    final title = TextEditingController(text: picked.files.single.name);
    String category = 'other';
    String visibility = 'private';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Upload document'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const ['id', 'certificate', 'property', 'medical', 'receipt', 'other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setLocal(() => category = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(labelText: 'Visibility'),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'desk', child: Text('Shared desk')),
                ],
                onChanged: (v) => setLocal(() => visibility = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
          ],
        ),
      ),
    );

    if (confirmed != true || title.text.trim().isEmpty) return;
    try {
      await service.uploadDocument(
        title: title.text.trim(),
        category: category,
        fileName: picked.files.single.name,
        bytes: picked.files.single.bytes!,
        visibility: visibility,
      );
      refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
        title: 'Documents & Vault',
        subtitle: 'Upload, organize and securely store your important records.',
        action: FilledButton.icon(onPressed: upload, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
            final items = snap.data ?? [];
            if (items.isEmpty) return const _EmptyState(icon: Icons.folder_open, text: 'No documents yet');
            return Column(
              children: items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                  title: Text(item['title'] ?? 'Document'),
                  subtitle: Text('${item['category'] ?? 'other'} · ${item['visibility'] ?? 'private'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await service.deleteDocument(item['id'], item['storage_path']);
                        refresh();
                      }
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))],
                  ),
                ),
              )).toList(),
            );
          },
        ),
      );
}

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = service.bills(); }
  void refresh() => setState(() => future = service.bills());

  Future<void> add() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    DateTime? due;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Add bill'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Bill name')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        const SizedBox(height: 12),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(due == null ? 'Choose due date' : 'Due ${due!.toLocal().toString().split(' ').first}'), trailing: const Icon(Icons.calendar_month), onTap: () async {
          final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
          if (picked != null) setLocal(() => due = picked);
        }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add'))],
    )));
    final parsed = double.tryParse(amount.text.trim());
    if (ok == true && title.text.trim().isNotEmpty && parsed != null) {
      await service.addBill(title: title.text.trim(), amount: parsed, dueDate: due);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
    title: 'Bills & Payments', subtitle: 'Track amounts, due dates and payment status.',
    action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add bill')),
    child: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
      final items = snap.data ?? [];
      if (items.isEmpty) return const _EmptyState(icon: Icons.receipt_long_outlined, text: 'No bills yet');
      return Column(children: items.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
        leading: Icon(item['status'] == 'paid' ? Icons.check_circle : Icons.schedule),
        title: Text(item['title'] ?? 'Bill'),
        subtitle: Text('${item['due_date'] ?? 'No due date'} · ${item['status']}'),
        trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          PopupMenuButton<String>(onSelected: (value) async {
            if (value == 'paid' || value == 'unpaid') await service.setBillStatus(item['id'], value);
            if (value == 'delete') await service.deleteBill(item['id']);
            refresh();
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'paid', child: Text('Mark paid')),
            PopupMenuItem(value: 'unpaid', child: Text('Mark unpaid')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ]),
        ]),
      ))).toList());
    }),
  );
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = service.tasks(); }
  void refresh() => setState(() => future = service.tasks());

  Future<void> add() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String priority = 'medium';
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Create task'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Task')),
        const SizedBox(height: 12),
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const ['low','medium','high'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setLocal(() => priority = v!)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
    )));
    if (ok == true && title.text.trim().isNotEmpty) {
      await service.addTask(title: title.text.trim(), description: description.text.trim(), priority: priority);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
    title: 'Tasks', subtitle: 'Create responsibilities and track progress.',
    action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add_task), label: const Text('Create task')),
    child: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
      final items = snap.data ?? [];
      if (items.isEmpty) return const _EmptyState(icon: Icons.task_alt, text: 'No tasks yet');
      return Column(children: items.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: CheckboxListTile(
        value: item['status'] == 'completed',
        onChanged: (value) async { await service.setTaskStatus(item['id'], value == true ? 'completed' : 'pending'); refresh(); },
        title: Text(item['title'] ?? 'Task'),
        subtitle: Text('${item['priority']} priority${(item['description'] ?? '').toString().isEmpty ? '' : ' · ${item['description']}'}'),
        secondary: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await service.deleteTask(item['id']); refresh(); }),
      ))).toList());
    }),
  );
}

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});
  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); future = service.khataEntries(); }
  void refresh() => setState(() => future = service.khataEntries());

  Future<void> add() async {
    final person = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    bool theyOweMe = true;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Add Khata entry'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: person, decoration: const InputDecoration(labelText: 'Person')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        const SizedBox(height: 12),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('They owe me')), ButtonSegment(value: false, label: Text('I owe them'))], selected: {theyOweMe}, onSelectionChanged: (v) => setLocal(() => theyOweMe = v.first)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add'))],
    )));
    final parsed = double.tryParse(amount.text.trim());
    if (ok == true && person.text.trim().isNotEmpty && parsed != null) {
      await service.addKhataEntry(amount: parsed, note: note.text.trim(), counterpartyName: person.text.trim(), theyOweMe: theyOweMe);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
    title: 'Khata', subtitle: 'Track personal balances with people you trust.',
    action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add entry')),
    child: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
      final items = snap.data ?? [];
      if (items.isEmpty) return const _EmptyState(icon: Icons.account_balance_wallet_outlined, text: 'No Khata entries yet');
      return Column(children: items.map((item) {
        final receivable = item['direction'] == 'receivable';
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: CircleAvatar(child: Icon(receivable ? Icons.south_west : Icons.north_east)),
          title: Text(item['counterparty_name'] ?? 'Person'),
          subtitle: Text('${item['note'] ?? ''} · ${item['status']}'),
          trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${receivable ? '+' : '-'} Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            PopupMenuButton<String>(onSelected: (value) async {
              if (value == 'settle') await service.settleKhata(item['id']);
              if (value == 'delete') await service.deleteKhata(item['id']);
              refresh();
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'settle', child: Text('Mark settled')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
          ]),
        ));
      }).toList());
    }),
  );
}

class _ModuleScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;
  final Widget child;
  const _ModuleScaffold({required this.title, required this.subtitle, required this.action, required this.child});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.black54))]),
        action,
      ]),
      const SizedBox(height: 24),
      child,
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(42), child: Column(children: [Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(text, style: const TextStyle(fontWeight: FontWeight.w700))])));
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.error_outline, size: 42), const SizedBox(height: 10), Text(error, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])));
}
