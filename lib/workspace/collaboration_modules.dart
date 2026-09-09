import 'package:flutter/material.dart';
import '../core/app_semantics.dart';
import '../services/workspace_service.dart';
import 'task_bill_detail_screens.dart';

Future<bool> _confirmAction(BuildContext context, {required String title, required String message}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppSemantics.outgoing), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      ) ?? false;
}

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final service = WorkspaceService();
  late Future<List<dynamic>> future;
  String filter = 'all';
  String workspace = 'all';

  @override void initState() { super.initState(); _reload(); }
  void _reload() => future = Future.wait([service.bills(), service.desks()]);
  void refresh() => setState(_reload);

  Future<void> add() async {
    final desks = (await service.desks()).where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;
    final title = TextEditingController();
    final amount = TextEditingController();
    DateTime? due;
    String? deskId;
    String? assignedTo = service.currentUserId;
    List<Map<String, dynamic>> members = [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('Add bill'),
        content: SizedBox(width: 470, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Bill name')),
          const SizedBox(height: 12),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('bill-desk-$deskId'), initialValue: deskId, decoration: const InputDecoration(labelText: 'Workspace'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('Personal bill')), ...desks.map((d) => DropdownMenuItem<String?>(value: d['id'] as String, child: Text('${d['name']}')))],
            onChanged: (value) async {
              final rows = value == null ? <Map<String, dynamic>>[] : await service.deskMembers(value);
              setLocal(() { deskId = value; members = rows; assignedTo = value == null ? service.currentUserId : null; });
            },
          ),
          if (deskId != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('bill-assignee-$assignedTo'), initialValue: assignedTo, decoration: const InputDecoration(labelText: 'Responsible person'),
              items: members.map((m) => DropdownMenuItem<String>(value: m['user_id'] as String, child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'))).toList(),
              onChanged: (v) => setLocal(() => assignedTo = v),
            ),
          ],
          const SizedBox(height: 10),
          ListTile(contentPadding: EdgeInsets.zero, title: Text(due == null ? 'No due date' : 'Due ${_formatDate(due)}'), trailing: const Icon(Icons.calendar_month), onTap: () async {
            final picked = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now());
            if (picked != null) setLocal(() => due = picked);
          }),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () { final parsed = double.tryParse(amount.text.trim()); if (title.text.trim().isEmpty || parsed == null || parsed <= 0 || (deskId != null && assignedTo == null)) return; Navigator.pop(context, true); }, child: const Text('Add bill')),
        ],
      )),
    );
    final parsed = double.tryParse(amount.text.trim());
    if (ok == true && parsed != null) {
      try {
        await service.addBill(title: title.text, amount: parsed, dueDate: due, deskId: deskId, assignedTo: assignedTo);
        refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill added successfully.')));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add bill: $e'))); }
    }
    title.dispose(); amount.dispose();
  }

  List<Map<String, dynamic>> _statusFiltered(List<Map<String, dynamic>> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (filter == 'paid') return items.where((e) => e['status'] == 'paid').toList();
    if (filter == 'overdue') return items.where((e) { final d = DateTime.tryParse('${e['due_date'] ?? ''}'); return e['status'] != 'paid' && d != null && d.isBefore(today); }).toList();
    if (filter == 'upcoming') return items.where((e) { final d = DateTime.tryParse('${e['due_date'] ?? ''}'); return e['status'] != 'paid' && d != null && !d.isBefore(today); }).toList();
    return items;
  }

  List<Map<String, dynamic>> _workspaceFiltered(List<Map<String, dynamic>> items) {
    if (workspace == 'all') return items;
    if (workspace == 'personal') return items.where((e) => e['desk_id'] == null).toList();
    return items.where((e) => '${e['desk_id']}' == workspace).toList();
  }

  String _workspaceName(Map<String, dynamic> item, List<Map<String, dynamic>> desks) {
    if (item['desk_id'] == null) return 'Personal';
    final rows = desks.where((d) => '${d['id']}' == '${item['desk_id']}').toList();
    return rows.isEmpty ? 'Shared Desk' : '${rows.first['name']}';
  }

  @override Widget build(BuildContext context) => _ModuleScaffold(
    title: 'Bills & Payments', subtitle: 'Track payments by status and workspace.',
    action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add bill')),
    tabs: _FilterTabs(values: const {'all':'All','upcoming':'Upcoming','overdue':'Overdue','paid':'Paid'}, selected: filter, onChanged: (v) => setState(() => filter = v)),
    child: FutureBuilder<List<dynamic>>(future: future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
      final allBills = List<Map<String, dynamic>>.from(snap.data![0] as List);
      final desks = List<Map<String, dynamic>>.from(snap.data![1] as List);
      final workspaces = <String, String>{'all':'All spaces','personal':'Personal', for (final d in desks) '${d['id']}':'${d['name']}'};
      if (!workspaces.containsKey(workspace)) workspace = 'all';
      final items = _workspaceFiltered(_statusFiltered(allBills));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _WorkspaceTabs(values: workspaces, selected: workspace, onChanged: (v) => setState(() => workspace = v)),
        const SizedBox(height: 18),
        if (items.isEmpty) _EmptyState(icon: Icons.receipt_long_outlined, text: 'No bills in this section') else ...items.map((item) {
          final isOwner = item['owner_id'] == service.currentUserId;
          final status = '${item['status']}';
          final due = DateTime.tryParse('${item['due_date'] ?? ''}');
          final now = DateTime.now();
          final overdue = status != 'paid' && due != null && due.isBefore(DateTime(now.year, now.month, now.day));
          final semanticStatus = status == 'paid' ? 'paid' : overdue ? 'overdue' : 'pending';
          final color = AppSemantics.statusColor(semanticStatus);
          final workspaceName = _workspaceName(item, desks);
          return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(bill: item, workspaceName: workspaceName)));
              refresh();
            },
            leading: CircleAvatar(backgroundColor: AppSemantics.soft(color), child: Icon(status == 'paid' ? Icons.check_rounded : overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded, color: color)),
            title: Text('${item['title'] ?? 'Bill'}', style: TextStyle(fontWeight: FontWeight.w800, decoration: status == 'paid' ? TextDecoration.lineThrough : null)),
            subtitle: Wrap(spacing: 7, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _StatusPill(label: workspaceName, color: Theme.of(context).colorScheme.primary),
              if (item['due_date'] != null) Text('Due ${item['due_date']}'),
              _StatusPill(label: status == 'paid' ? 'Paid' : overdue ? 'Overdue' : 'Upcoming', color: color),
              if (item['assignee_name'] != null) Text('Responsible: ${item['assignee_name']}'),
            ]),
            trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Rs. ${item['amount']}', style: TextStyle(fontWeight: FontWeight.w900, color: status == 'paid' ? AppSemantics.incoming : overdue ? AppSemantics.outgoing : null)),
              PopupMenuButton<String>(onSelected: (value) async {
                try {
                  if (value == 'paid' || value == 'unpaid') await service.setBillStatus(item['id'], value);
                  if (value == 'delete' && await _confirmAction(context, title: 'Delete bill?', message: 'This permanently removes this bill.')) await service.deleteBill(item['id']);
                  refresh();
                } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update bill: $e'))); }
              }, itemBuilder: (_) => [if (status != 'paid') const PopupMenuItem(value: 'paid', child: Text('Mark paid')), if (status == 'paid') const PopupMenuItem(value: 'unpaid', child: Text('Mark unpaid')), if (isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
            ]),
          ));
        }),
      ]);
    }),
  );
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final service = WorkspaceService();
  late Future<List<dynamic>> future;
  String filter = 'all';
  String workspace = 'all';

  @override void initState() { super.initState(); _reload(); }
  void _reload() => future = Future.wait([service.tasks(), service.desks()]);
  void refresh() => setState(_reload);

  Future<void> add() async {
    final desks = (await service.desks()).where((d) => d['role'] != 'viewer').toList();
    if (!mounted) return;
    final title = TextEditingController();
    final description = TextEditingController();
    String priority = 'medium'; String? deskId; String? assigneeId = service.currentUserId; DateTime? due; List<Map<String, dynamic>> members = [];
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Assign task'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')),
        const SizedBox(height: 12), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
        const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const ['low','medium','high'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setLocal(() => priority = v ?? 'medium')),
        const SizedBox(height: 12), DropdownButtonFormField<String?>(key: ValueKey('task-desk-$deskId'), initialValue: deskId, decoration: const InputDecoration(labelText: 'Workspace'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Personal task')), ...desks.map((d) => DropdownMenuItem<String?>(value: d['id'] as String, child: Text('${d['name']}')))], onChanged: (value) async {
          final rows = value == null ? <Map<String,dynamic>>[] : await service.deskMembers(value);
          setLocal(() { deskId = value; members = rows; assigneeId = value == null ? service.currentUserId : null; });
        }),
        if (deskId != null) ...[const SizedBox(height: 12), DropdownButtonFormField<String>(key: ValueKey('task-assignee-$assigneeId'), initialValue: assigneeId, decoration: const InputDecoration(labelText: 'Assign to'), items: members.map((m) => DropdownMenuItem<String>(value: m['user_id'] as String, child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'))).toList(), onChanged: (v) => setLocal(() => assigneeId = v))],
        const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, title: Text(due == null ? 'No due date' : 'Due ${_formatDate(due)}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now()); if (picked != null) setLocal(() => due = picked); }),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (title.text.trim().isEmpty || (deskId != null && assigneeId == null)) return; Navigator.pop(context, true); }, child: const Text('Assign task'))],
    )));
    if (ok == true) {
      try {
        await service.addTask(title: title.text, description: description.text, priority: priority, deskId: deskId, assigneeId: assigneeId, dueDate: due);
        refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task assigned successfully.')));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create task: $e'))); }
    }
    title.dispose(); description.dispose();
  }

  List<Map<String,dynamic>> _statusFiltered(List<Map<String,dynamic>> items) {
    if (filter == 'my') return items.where((e) => e['creator_id'] == service.currentUserId && e['assignee_id'] == service.currentUserId && e['status'] != 'completed').toList();
    if (filter == 'assigned') return items.where((e) => e['assignee_id'] == service.currentUserId && e['creator_id'] != service.currentUserId && e['status'] != 'completed').toList();
    if (filter == 'completed') return items.where((e) => e['status'] == 'completed').toList();
    return items;
  }

  List<Map<String,dynamic>> _workspaceFiltered(List<Map<String,dynamic>> items) {
    if (workspace == 'all') return items;
    if (workspace == 'personal') return items.where((e) => e['desk_id'] == null).toList();
    return items.where((e) => '${e['desk_id']}' == workspace).toList();
  }

  String _workspaceName(Map<String, dynamic> item, List<Map<String, dynamic>> desks) {
    if (item['desk_id'] == null) return 'Personal';
    final rows = desks.where((d) => '${d['id']}' == '${item['desk_id']}').toList();
    return rows.isEmpty ? 'Shared Desk' : '${rows.first['name']}';
  }

  @override Widget build(BuildContext context) => _ModuleScaffold(
    title: 'Tasks', subtitle: 'Separate your work by responsibility and workspace.',
    action: FilledButton.icon(onPressed: add, icon: const Icon(Icons.assignment_add), label: const Text('Assign Task')),
    tabs: _FilterTabs(values: const {'all':'All','my':'My Tasks','assigned':'Assigned','completed':'Completed'}, selected: filter, onChanged: (v) => setState(() => filter = v)),
    child: FutureBuilder<List<dynamic>>(future: future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return _ErrorState(error: snap.error.toString(), onRetry: refresh);
      final allTasks = List<Map<String,dynamic>>.from(snap.data![0] as List);
      final desks = List<Map<String,dynamic>>.from(snap.data![1] as List);
      final workspaces = <String, String>{'all':'All spaces','personal':'Personal', for (final d in desks) '${d['id']}':'${d['name']}'};
      if (!workspaces.containsKey(workspace)) workspace = 'all';
      final items = _workspaceFiltered(_statusFiltered(allTasks));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _WorkspaceTabs(values: workspaces, selected: workspace, onChanged: (v) => setState(() => workspace = v)),
        const SizedBox(height: 18),
        if (items.isEmpty) const _EmptyState(icon: Icons.task_alt, text: 'No tasks in this section') else ...items.map((item) {
          final status = '${item['status']}';
          final priority = '${item['priority']}';
          final isCreator = item['creator_id'] == service.currentUserId;
          final statusColor = AppSemantics.statusColor(status);
          final priorityColor = AppSemantics.priorityColor(priority);
          final workspaceName = _workspaceName(item, desks);
          return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item, workspaceName: workspaceName)));
              refresh();
            },
            leading: CircleAvatar(backgroundColor: AppSemantics.soft(priorityColor), child: Icon(_priorityIcon(priority), color: priorityColor)),
            title: Text('${item['title'] ?? 'Task'}', style: TextStyle(fontWeight: FontWeight.w800, decoration: status == 'completed' ? TextDecoration.lineThrough : null, color: status == 'completed' ? AppSemantics.incoming : null)),
            subtitle: Wrap(spacing: 7, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _StatusPill(label: workspaceName, color: Theme.of(context).colorScheme.primary),
              _StatusPill(label: '${priority[0].toUpperCase()}${priority.substring(1)}', color: priorityColor),
              _StatusPill(label: _statusLabel(status), color: statusColor),
              if (item['due_date'] != null) Text('Due ${_formatDate(DateTime.tryParse('${item['due_date']}'))}'),
              if (item['assignee_name'] != null) Text('Assigned: ${item['assignee_name']}'),
            ]),
            trailing: PopupMenuButton<String>(onSelected: (value) async {
              try {
                if (const {'pending','in_progress','completed'}.contains(value)) await service.setTaskStatus(item['id'], value);
                if (value == 'delete' && await _confirmAction(context, title: 'Delete task?', message: 'This permanently removes this task.')) await service.deleteTask(item['id']);
                refresh();
              } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update task: $e'))); }
            }, itemBuilder: (_) => [if (status != 'pending') const PopupMenuItem(value: 'pending', child: Text('Set pending')), if (status != 'in_progress') const PopupMenuItem(value: 'in_progress', child: Text('Set in progress')), if (status != 'completed') const PopupMenuItem(value: 'completed', child: Text('Mark completed')), if (isCreator) const PopupMenuItem(value: 'delete', child: Text('Delete'))]),
          ));
        }),
      ]);
    }),
  );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: AppSemantics.soft(color), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .35))),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

class _FilterTabs extends StatelessWidget {
  final Map<String,String> values; final String selected; final ValueChanged<String> onChanged;
  const _FilterTabs({required this.values, required this.selected, required this.onChanged});
  @override Widget build(BuildContext context) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: values.entries.map((e) => ButtonSegment(value: e.key, label: Text(e.value))).toList(), selected: {selected}, onSelectionChanged: (v) => onChanged(v.first)));
}

class _WorkspaceTabs extends StatelessWidget {
  final Map<String,String> values; final String selected; final ValueChanged<String> onChanged;
  const _WorkspaceTabs({required this.values, required this.selected, required this.onChanged});
  @override Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Wrap(spacing: 8, children: values.entries.map((e) => ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (_) => onChanged(e.key))).toList()),
  );
}

class _ModuleScaffold extends StatelessWidget {
  final String title; final String subtitle; final Widget action; final Widget child; final Widget? tabs;
  const _ModuleScaffold({required this.title, required this.subtitle, required this.action, required this.child, this.tabs});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]), action]),
    if (tabs != null) ...[const SizedBox(height: 20), tabs!], const SizedBox(height: 20), child,
  ]);
}

class _EmptyState extends StatelessWidget { final IconData icon; final String text; const _EmptyState({required this.icon, required this.text}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(36), child: Column(children: [Icon(icon, size: 44), const SizedBox(height: 10), Text(text, textAlign: TextAlign.center)]))); }
class _ErrorState extends StatelessWidget { final String error; final VoidCallback onRetry; const _ErrorState({required this.error, required this.onRetry}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Icon(Icons.error_outline, color: AppSemantics.outgoing, size: 38), const SizedBox(height: 8), Text(error, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))]))); }

String _formatDate(DateTime? value) { if (value == null) return 'No date'; final d = value.toLocal(); return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}'; }
String _statusLabel(String status) => status.replaceAll('_', ' ');
IconData _priorityIcon(String priority) => priority == 'high' ? Icons.priority_high : priority == 'low' ? Icons.low_priority : Icons.drag_handle;
