import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
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
  void initState() {
    super.initState();
    future = service.bills();
  }

  void refresh() => setState(() => future = service.bills());

  Future<void> add() async {
    final allDesks = await service.desks();
    final desks = allDesks.where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;

    final title = TextEditingController();
    final amount = TextEditingController();
    DateTime? due;
    String? deskId;
    String? assignedTo = service.currentUserId;
    List<Map<String, dynamic>> members = [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add bill'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Bill name')),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('bill-desk-$deskId'),
                  initialValue: deskId,
                  decoration: const InputDecoration(labelText: 'Workspace'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Personal bill')),
                    ...desks.map((d) => DropdownMenuItem<String?>(value: d['id'] as String, child: Text('${d['name']}'))),
                  ],
                  onChanged: (value) async {
                    final rows = value == null ? <Map<String, dynamic>>[] : await service.deskMembers(value);
                    setLocal(() {
                      deskId = value;
                      members = rows;
                      assignedTo = value == null ? service.currentUserId : null;
                    });
                  },
                ),
                if (deskId != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('bill-assignee-$assignedTo'),
                    initialValue: assignedTo,
                    decoration: const InputDecoration(labelText: 'Responsible person'),
                    items: members.map((m) => DropdownMenuItem<String>(
                      value: m['user_id'] as String,
                      child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'),
                    )).toList(),
                    onChanged: (v) => setLocal(() => assignedTo = v),
                  ),
                ],
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(due == null ? 'No due date selected' : 'Due ${_formatDate(due)}'),
                  subtitle: const Text('Due dates appear on your Home dashboard.'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: due ?? DateTime.now(),
                    );
                    if (picked != null) setLocal(() => due = picked);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (title.text.trim().isEmpty || parsed == null || parsed <= 0) return;
                if (deskId != null && assignedTo == null) return;
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    final parsed = double.tryParse(amount.text.trim());
    if (ok == true && parsed != null) {
      try {
        await service.addBill(
          title: title.text,
          amount: parsed,
          dueDate: due,
          deskId: deskId,
          assignedTo: assignedTo,
        );
        refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill added.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add bill: $e')));
      }
    }
    title.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
        title: 'Bills & Payments',
        subtitle: 'You see bills you own, bills assigned to you, and bills you manage.',
        action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add bill')),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
            final items = snap.data ?? [];
            if (items.isEmpty) return const _EmptyState(icon: Icons.receipt_long_outlined, text: 'No relevant bills yet');

            return Column(children: items.map((item) {
              final isOwner = item['owner_id'] == service.currentUserId;
              final status = '${item['status']}';
              final assignee = item['assignee_name']?.toString();
              final due = item['due_date']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(status == 'paid' ? Icons.check : Icons.receipt_long_outlined)),
                  title: Text(item['title'] ?? 'Bill', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (due != null) 'Due $due',
                    status,
                    if (assignee != null) 'Responsible: $assignee',
                  ].join(' · ')),
                  trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        try {
                          if (value == 'paid' || value == 'unpaid') {
                            await service.setBillStatus(item['id'], value);
                          } else if (value == 'delete') {
                            final ok = await _confirmAction(
                              context,
                              title: 'Delete bill?',
                              message: 'This removes the bill from myDesk. This cannot be undone.',
                            );
                            if (!ok) return;
                            await service.deleteBill(item['id']);
                          }
                          refresh();
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update bill: $e')));
                        }
                      },
                      itemBuilder: (_) => [
                        if (status != 'paid') const PopupMenuItem(value: 'paid', child: Text('Mark paid')),
                        if (status == 'paid') const PopupMenuItem(value: 'unpaid', child: Text('Mark unpaid')),
                        if (isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ]),
                ),
              );
            }).toList());
          },
        ),
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
  void initState() {
    super.initState();
    future = service.tasks();
  }

  void refresh() => setState(() => future = service.tasks());

  Future<void> add() async {
    final allDesks = await service.desks();
    final desks = allDesks.where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;

    final title = TextEditingController();
    final description = TextEditingController();
    String priority = 'medium';
    String? deskId;
    String? assigneeId = service.currentUserId;
    DateTime? due;
    List<Map<String, dynamic>> members = [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create task'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')),
                const SizedBox(height: 12),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const ['low', 'medium', 'high'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('task-desk-$deskId'),
                  initialValue: deskId,
                  decoration: const InputDecoration(labelText: 'Workspace'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Personal task')),
                    ...desks.map((d) => DropdownMenuItem<String?>(value: d['id'] as String, child: Text('${d['name']}'))),
                  ],
                  onChanged: (value) async {
                    final rows = value == null ? <Map<String, dynamic>>[] : await service.deskMembers(value);
                    setLocal(() {
                      deskId = value;
                      members = rows;
                      assigneeId = value == null ? service.currentUserId : null;
                    });
                  },
                ),
                if (deskId != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('task-assignee-$assigneeId'),
                    initialValue: assigneeId,
                    decoration: const InputDecoration(labelText: 'Assign to'),
                    items: members.map((m) => DropdownMenuItem<String>(
                      value: m['user_id'] as String,
                      child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'),
                    )).toList(),
                    onChanged: (v) => setLocal(() => assigneeId = v),
                  ),
                ],
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(due == null ? 'No due date selected' : 'Due ${_formatDate(due)}'),
                  subtitle: const Text('Due tasks are surfaced on Home.'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: due ?? DateTime.now(),
                    );
                    if (picked != null) setLocal(() => due = picked);
                  },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                if (deskId != null && assigneeId == null) return;
                Navigator.pop(context, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await service.addTask(
          title: title.text,
          description: description.text,
          priority: priority,
          deskId: deskId,
          assigneeId: assigneeId,
          dueDate: due,
        );
        refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create task: $e')));
      }
    }
    title.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
        title: 'Tasks',
        subtitle: 'You see tasks you created, tasks assigned to you, and tasks you manage.',
        action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add_task), label: const Text('Create task')),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
            final items = snap.data ?? [];
            if (items.isEmpty) return const _EmptyState(icon: Icons.task_alt, text: 'No relevant tasks yet');

            return Column(children: items.map((item) {
              final status = '${item['status']}';
              final isCreator = item['creator_id'] == service.currentUserId;
              final assignee = item['assignee_name']?.toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_priorityIcon('${item['priority']}'))),
                  title: Text(item['title'] ?? 'Task', style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                  )),
                  subtitle: Text([
                    '${item['priority']} priority',
                    _statusLabel(status),
                    if (item['due_date'] != null) 'Due ${_formatDate(DateTime.tryParse('${item['due_date']}'))}',
                    if (assignee != null) 'Assigned: $assignee',
                    if ((item['description'] ?? '').toString().trim().isNotEmpty) '${item['description']}',
                  ].join(' · ')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      try {
                        if (value == 'pending' || value == 'in_progress' || value == 'completed') {
                          await service.setTaskStatus(item['id'], value);
                        } else if (value == 'delete') {
                          final ok = await _confirmAction(
                            context,
                            title: 'Delete task?',
                            message: 'This permanently removes the task.',
                          );
                          if (!ok) return;
                          await service.deleteTask(item['id']);
                        }
                        refresh();
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update task: $e')));
                      }
                    },
                    itemBuilder: (_) => [
                      if (status != 'pending') const PopupMenuItem(value: 'pending', child: Text('Mark pending')),
                      if (status != 'in_progress') const PopupMenuItem(value: 'in_progress', child: Text('Mark in progress')),
                      if (status != 'completed') const PopupMenuItem(value: 'completed', child: Text('Mark completed')),
                      if (isCreator) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            }).toList());
          },
        ),
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
  void initState() {
    super.initState();
    future = service.khataEntries();
  }

  void refresh() => setState(() => future = service.khataEntries());

  Future<void> add() async {
    final person = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    bool theyOweMe = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Khata entry'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: person, autofocus: true, decoration: const InputDecoration(labelText: 'Person')),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. '),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('They owe me')),
                    ButtonSegment(value: false, label: Text('I owe them')),
                  ],
                  selected: {theyOweMe},
                  onSelectionChanged: (v) => setLocal(() => theyOweMe = v.first),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (person.text.trim().isEmpty || parsed == null || parsed <= 0) return;
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    final parsed = double.tryParse(amount.text.trim());
    if (ok == true && parsed != null) {
      try {
        await service.addKhataEntry(
          amount: parsed,
          note: note.text,
          counterpartyName: person.text,
          theyOweMe: theyOweMe,
        );
        refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add entry: $e')));
      }
    }
    person.dispose();
    amount.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) => _ModuleScaffold(
        title: 'Khata',
        subtitle: 'Personal money notes for what you owe and what others owe you.',
        action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add entry')),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
            final items = snap.data ?? [];
            if (items.isEmpty) return const _EmptyState(icon: Icons.account_balance_wallet_outlined, text: 'No Khata entries yet');

            return Column(children: items.map((item) {
              final receivable = item['direction'] == 'receivable';
              final settled = item['status'] == 'settled';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(receivable ? Icons.south_west : Icons.north_east)),
                  title: Text(item['counterparty_name'] ?? 'Person', style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: settled ? TextDecoration.lineThrough : null,
                  )),
                  subtitle: Text([
                    receivable ? 'They owe you' : 'You owe them',
                    settled ? 'settled' : 'open',
                    if ((item['note'] ?? '').toString().trim().isNotEmpty) '${item['note']}',
                  ].join(' · ')),
                  trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('${receivable ? '+' : '-'} Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        try {
                          if (value == 'settle') {
                            await service.settleKhata(item['id']);
                          } else if (value == 'delete') {
                            final ok = await _confirmAction(
                              context,
                              title: 'Delete Khata entry?',
                              message: 'This permanently removes the money note.',
                            );
                            if (!ok) return;
                            await service.deleteKhata(item['id']);
                          }
                          refresh();
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update entry: $e')));
                        }
                      },
                      itemBuilder: (_) => [
                        if (!settled) const PopupMenuItem(value: 'settle', child: Text('Mark settled')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ]),
                ),
              );
            }).toList());
          },
        ),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650), child: Text(subtitle)),
              ]),
              action,
            ],
          ),
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
}

String _formatDate(DateTime? date) {
  if (date == null) return 'No due date';
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _statusLabel(String status) {
  switch (status) {
    case 'in_progress': return 'in progress';
    case 'completed': return 'completed';
    default: return 'pending';
  }
}

IconData _priorityIcon(String priority) {
  switch (priority) {
    case 'high': return Icons.priority_high;
    case 'low': return Icons.low_priority;
    default: return Icons.drag_handle;
  }
}
