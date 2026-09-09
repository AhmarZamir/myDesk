import 'package:flutter/material.dart';
import '../core/app_semantics.dart';
import '../services/workspace_service.dart';

class BillDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bill;
  final String workspaceName;
  const BillDetailScreen({super.key, required this.bill, required this.workspaceName});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final _service = WorkspaceService();
  late Map<String, dynamic> _bill;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bill = Map<String, dynamic>.from(widget.bill);
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _service.setBillStatus('${_bill['id']}', status);
      if (mounted) setState(() => _bill['status'] = status);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update bill: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete bill?'),
            content: const Text('This permanently removes this bill.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppSemantics.outgoing),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!ok) return;
    await _service.deleteBill('${_bill['id']}');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_bill['status']}';
    final due = DateTime.tryParse('${_bill['due_date'] ?? ''}');
    final today = DateTime.now();
    final overdue = status != 'paid' && due != null && due.isBefore(DateTime(today.year, today.month, today.day));
    final semantic = status == 'paid' ? 'paid' : overdue ? 'overdue' : 'pending';
    final color = AppSemantics.statusColor(semantic);
    final isOwner = _bill['owner_id'] == _service.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill details', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(backgroundColor: AppSemantics.soft(color), child: Icon(status == 'paid' ? Icons.check_rounded : overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded, color: color)),
                  const SizedBox(width: 14),
                  Expanded(child: Text('${_bill['title'] ?? 'Bill'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 22),
                _DetailRow(label: 'Amount', value: 'Rs. ${_bill['amount']}'),
                _DetailRow(label: 'Status', value: status == 'paid' ? 'Paid' : overdue ? 'Overdue' : 'Upcoming', valueColor: color),
                _DetailRow(label: 'Workspace', value: widget.workspaceName),
                if (_bill['assignee_name'] != null) _DetailRow(label: 'Responsible', value: '${_bill['assignee_name']}'),
                if (_bill['due_date'] != null) _DetailRow(label: 'Due date', value: '${_bill['due_date']}'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (status != 'paid') FilledButton.icon(onPressed: _busy ? null : () => _setStatus('paid'), icon: const Icon(Icons.check), label: const Text('Mark paid')),
            if (status == 'paid') OutlinedButton.icon(onPressed: _busy ? null : () => _setStatus('unpaid'), icon: const Icon(Icons.undo), label: const Text('Mark unpaid')),
            if (isOwner) OutlinedButton.icon(onPressed: _busy ? null : _delete, icon: Icon(Icons.delete_outline, color: AppSemantics.outgoing), label: Text('Delete', style: TextStyle(color: AppSemantics.outgoing))),
          ]),
        ],
      ),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String workspaceName;
  const TaskDetailScreen({super.key, required this.task, required this.workspaceName});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _service = WorkspaceService();
  late Map<String, dynamic> _task;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _service.setTaskStatus('${_task['id']}', status);
      if (mounted) setState(() => _task['status'] = status);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update task: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete task?'),
            content: const Text('This permanently removes this task.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppSemantics.outgoing),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!ok) return;
    await _service.deleteTask('${_task['id']}');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_task['status']}';
    final priority = '${_task['priority']}';
    final statusColor = AppSemantics.statusColor(status);
    final priorityColor = AppSemantics.priorityColor(priority);
    final isCreator = _task['creator_id'] == _service.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Task details', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(backgroundColor: AppSemantics.soft(priorityColor), child: Icon(priority == 'high' ? Icons.priority_high : priority == 'low' ? Icons.low_priority : Icons.drag_handle, color: priorityColor)),
                  const SizedBox(width: 14),
                  Expanded(child: Text('${_task['title'] ?? 'Task'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 22),
                _DetailRow(label: 'Status', value: status.replaceAll('_', ' '), valueColor: statusColor),
                _DetailRow(label: 'Priority', value: priority, valueColor: priorityColor),
                _DetailRow(label: 'Workspace', value: widget.workspaceName),
                if (_task['assignee_name'] != null) _DetailRow(label: 'Assigned to', value: '${_task['assignee_name']}'),
                if (_task['due_date'] != null) _DetailRow(label: 'Due date', value: _date(_task['due_date'])),
                if ((_task['description'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${_task['description']}', style: const TextStyle(fontSize: 16, height: 1.45)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (status != 'pending') OutlinedButton(onPressed: _busy ? null : () => _setStatus('pending'), child: const Text('Set pending')),
            if (status != 'in_progress') OutlinedButton(onPressed: _busy ? null : () => _setStatus('in_progress'), child: const Text('Set in progress')),
            if (status != 'completed') FilledButton.icon(onPressed: _busy ? null : () => _setStatus('completed'), icon: const Icon(Icons.check), label: const Text('Mark completed')),
            if (isCreator) OutlinedButton.icon(onPressed: _busy ? null : _delete, icon: Icon(Icons.delete_outline, color: AppSemantics.outgoing), label: Text('Delete', style: TextStyle(color: AppSemantics.outgoing))),
          ]),
        ],
      ),
    );
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse('${value ?? ''}');
    if (d == null) return 'No date';
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 115, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor))),
        ]),
      );
}
