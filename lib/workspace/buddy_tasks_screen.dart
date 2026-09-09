import 'package:flutter/material.dart';
import '../core/app_semantics.dart';
import '../services/workspace_service.dart';
import 'task_bill_detail_screens.dart';

class BuddyTasksScreen extends StatefulWidget {
  const BuddyTasksScreen({super.key});

  @override
  State<BuddyTasksScreen> createState() => _BuddyTasksScreenState();
}

class _BuddyTasksScreenState extends State<BuddyTasksScreen> {
  final _service = WorkspaceService();
  late Future<List<dynamic>> _future;
  String _filter = 'all';
  String _workspace = 'all';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = Future.wait([_service.tasks(), _service.desks(), _service.buddies()]);
  void _refresh() => setState(_reload);

  Future<void> _assignTask() async {
    final results = await Future.wait([_service.desks(), _service.buddies()]);
    if (!mounted) return;

    final desks = List<Map<String, dynamic>>.from(results[0]).where((d) => d['role'] != 'viewer').toList();
    final buddies = List<Map<String, dynamic>>.from(results[1]);
    final title = TextEditingController();
    final description = TextEditingController();

    String priority = 'medium';
    String source = 'personal';
    String? deskId;
    String? assigneeId = _service.currentUserId;
    DateTime? due;
    List<Map<String, dynamic>> members = [];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Assign task'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const SizedBox(height: 16),
                const Text('Assign through', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'personal', icon: Icon(Icons.person_outline), label: Text('Personal')),
                    ButtonSegment(value: 'desk', icon: Icon(Icons.groups_outlined), label: Text('Shared Desk')),
                    ButtonSegment(value: 'buddy', icon: Icon(Icons.people_outline), label: Text('Buddy')),
                  ],
                  selected: {source},
                  onSelectionChanged: (value) => setLocal(() {
                    source = value.first;
                    deskId = null;
                    members = [];
                    assigneeId = source == 'personal' ? _service.currentUserId : null;
                  }),
                ),
                if (source == 'desk') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: deskId,
                    decoration: const InputDecoration(labelText: 'Choose Shared Desk'),
                    items: desks.map((d) => DropdownMenuItem<String>(value: '${d['id']}', child: Text('${d['name']}'))).toList(),
                    onChanged: (value) async {
                      final rows = value == null ? <Map<String, dynamic>>[] : await _service.deskMembers(value);
                      setLocal(() {
                        deskId = value;
                        members = rows;
                        assigneeId = null;
                      });
                    },
                  ),
                  if (desks.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('You do not have a writable Shared Desk.')),
                  if (deskId != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: assigneeId,
                      decoration: const InputDecoration(labelText: 'Assign to'),
                      items: members
                          .map((m) => DropdownMenuItem<String>(
                                value: '${m['user_id']}',
                                child: Text('${m['full_name']}${m['is_me'] == true ? ' (You)' : ''}'),
                              ))
                          .toList(),
                      onChanged: (v) => setLocal(() => assigneeId = v),
                    ),
                  ],
                ],
                if (source == 'buddy') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: assigneeId,
                    decoration: const InputDecoration(labelText: 'Choose Buddy'),
                    items: buddies
                        .map((b) => DropdownMenuItem<String>(value: '${b['user_id']}', child: Text('${b['full_name']}')))
                        .toList(),
                    onChanged: (v) => setLocal(() => assigneeId = v),
                  ),
                  if (buddies.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('No Buddies yet. Add a Buddy first.')),
                ],
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(due == null ? 'No due date' : 'Due ${_formatDate(due)}'),
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
                if (source == 'desk' && (deskId == null || assigneeId == null)) return;
                if (source == 'buddy' && assigneeId == null) return;
                Navigator.pop(context, true);
              },
              child: const Text('Assign task'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _service.addTask(
          title: title.text,
          description: description.text,
          priority: priority,
          deskId: source == 'desk' ? deskId : null,
          assigneeId: assigneeId,
          dueDate: due,
        );
        _refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task assigned successfully.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create task: $e')));
      }
    }

    title.dispose();
    description.dispose();
  }

  List<Map<String, dynamic>> _statusFiltered(List<Map<String, dynamic>> items) {
    if (_filter == 'my') {
      return items
          .where((e) => e['creator_id'] == _service.currentUserId && e['assignee_id'] == _service.currentUserId && e['status'] != 'completed')
          .toList();
    }
    if (_filter == 'assigned') {
      return items
          .where((e) => e['assignee_id'] == _service.currentUserId && e['creator_id'] != _service.currentUserId && e['status'] != 'completed')
          .toList();
    }
    if (_filter == 'completed') return items.where((e) => e['status'] == 'completed').toList();
    return items;
  }

  bool _isBuddyTask(Map<String, dynamic> task, Set<String> buddyIds) {
    if (task['desk_id'] != null) return false;
    final creator = task['creator_id']?.toString();
    final assignee = task['assignee_id']?.toString();
    if (creator == _service.currentUserId && assignee != _service.currentUserId) return buddyIds.contains(assignee);
    if (assignee == _service.currentUserId && creator != _service.currentUserId) return buddyIds.contains(creator);
    return false;
  }

  List<Map<String, dynamic>> _workspaceFiltered(List<Map<String, dynamic>> items, Set<String> buddyIds) {
    if (_workspace == 'all') return items;
    if (_workspace == 'personal') {
      return items.where((e) => e['desk_id'] == null && !_isBuddyTask(e, buddyIds)).toList();
    }
    if (_workspace == 'buddies') return items.where((e) => _isBuddyTask(e, buddyIds)).toList();
    return items.where((e) => '${e['desk_id']}' == _workspace).toList();
  }

  String _workspaceName(Map<String, dynamic> task, List<Map<String, dynamic>> desks, List<Map<String, dynamic>> buddies) {
    if (task['desk_id'] != null) {
      final rows = desks.where((d) => '${d['id']}' == '${task['desk_id']}').toList();
      return rows.isEmpty ? 'Shared Desk' : '${rows.first['name']}';
    }
    final buddyIds = buddies.map((b) => '${b['user_id']}').toSet();
    if (_isBuddyTask(task, buddyIds)) return 'Buddy';
    return 'Personal';
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tasks', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('Assign work to yourself, Shared Desk members, or Buddies.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
            FilledButton.icon(onPressed: _assignTask, icon: const Icon(Icons.assignment_add), label: const Text('Assign Task')),
          ],
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const {
              'all': 'All',
              'my': 'My Tasks',
              'assigned': 'Assigned',
              'completed': 'Completed',
            }.entries.map((e) => ButtonSegment(value: e.key, label: Text(e.value))).toList(),
            selected: {_filter},
            onSelectionChanged: (v) => setState(() => _filter = v.first),
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
            if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load tasks: ${snap.error}')));

            final tasks = List<Map<String, dynamic>>.from(snap.data![0] as List);
            final desks = List<Map<String, dynamic>>.from(snap.data![1] as List);
            final buddies = List<Map<String, dynamic>>.from(snap.data![2] as List);
            final buddyIds = buddies.map((b) => '${b['user_id']}').toSet();
            final workspaces = <String, String>{
              'all': 'All spaces',
              'personal': 'Personal',
              'buddies': 'Buddies',
              for (final d in desks) '${d['id']}': '${d['name']}',
            };
            if (!workspaces.containsKey(_workspace)) _workspace = 'all';
            final items = _workspaceFiltered(_statusFiltered(tasks), buddyIds);

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8,
                  children: workspaces.entries
                      .map((e) => ChoiceChip(label: Text(e.value), selected: _workspace == e.key, onSelected: (_) => setState(() => _workspace = e.key)))
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(34), child: Center(child: Text('No tasks in this section.'))))
              else
                ...items.map((item) {
                  final status = '${item['status']}';
                  final priority = '${item['priority']}';
                  final isCreator = item['creator_id'] == _service.currentUserId;
                  final statusColor = AppSemantics.statusColor(status);
                  final priorityColor = AppSemantics.priorityColor(priority);
                  final workspaceName = _workspaceName(item, desks, buddies);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item, workspaceName: workspaceName)));
                        _refresh();
                      },
                      leading: CircleAvatar(backgroundColor: AppSemantics.soft(priorityColor), child: Icon(_priorityIcon(priority), color: priorityColor)),
                      title: Text(
                        '${item['title'] ?? 'Task'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                          color: status == 'completed' ? AppSemantics.incoming : null,
                        ),
                      ),
                      subtitle: Wrap(spacing: 7, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        _Pill(label: workspaceName, color: workspaceName == 'Buddy' ? AppSemantics.info : Theme.of(context).colorScheme.primary),
                        _Pill(label: priority, color: priorityColor),
                        _Pill(label: status.replaceAll('_', ' '), color: statusColor),
                        if (item['due_date'] != null) Text('Due ${_formatDate(DateTime.tryParse('${item['due_date']}'))}'),
                        if (item['assignee_name'] != null) Text('Assigned: ${item['assignee_name']}'),
                      ]),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          try {
                            if (const {'pending', 'in_progress', 'completed'}.contains(value)) await _service.setTaskStatus('${item['id']}', value);
                            if (value == 'delete' && isCreator) await _service.deleteTask('${item['id']}');
                            _refresh();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update task: $e')));
                          }
                        },
                        itemBuilder: (_) => [
                          if (status != 'pending') const PopupMenuItem(value: 'pending', child: Text('Set pending')),
                          if (status != 'in_progress') const PopupMenuItem(value: 'in_progress', child: Text('Set in progress')),
                          if (status != 'completed') const PopupMenuItem(value: 'completed', child: Text('Mark completed')),
                          if (isCreator) const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: AppSemantics.soft(color), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .35))),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

String _formatDate(DateTime? value) {
  if (value == null) return 'No date';
  final d = value.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

IconData _priorityIcon(String priority) {
  if (priority == 'high') return Icons.priority_high;
  if (priority == 'low') return Icons.low_priority;
  return Icons.drag_handle;
}
