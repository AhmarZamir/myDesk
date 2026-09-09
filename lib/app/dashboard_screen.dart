import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/workspace_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = WorkspaceService();
  final _auth = AuthService();
  final _notifications = NotificationService();
  late Future<Map<String,dynamic>> _future;
  late Future<Map<String,dynamic>?> _profile;
  late Future<List<Map<String,dynamic>>> _activity;

  @override void initState() { super.initState(); _load(); }
  void _load() { _future = _service.dashboardSnapshot(); _profile = _auth.fetchProfile(); _activity = _notifications.recent(limit: 8); }
  Future<void> _reload() async { setState(_load); await Future.wait([_future, _profile, _activity]); }

  Future<void> _openSearch() async {
    final results = await Future.wait<dynamic>([_service.documents(), _service.bills(), _service.tasks(), _service.buddies(), _service.desks()]);
    if (!mounted) return;
    final all = <Map<String,dynamic>>[
      ...List<Map<String,dynamic>>.from(results[0]).map((e) => {'type':'Document','title':'${e['title']}','subtitle':'${e['category']}','target':1}),
      ...List<Map<String,dynamic>>.from(results[1]).map((e) => {'type':'Bill','title':'${e['title']}','subtitle':'Rs. ${e['amount']} · ${e['status']}','target':2}),
      ...List<Map<String,dynamic>>.from(results[2]).map((e) => {'type':'Task','title':'${e['title']}','subtitle':'${e['status']} · ${e['priority']}','target':3}),
      ...List<Map<String,dynamic>>.from(results[3]).map((e) => {'type':'Buddy','title':'${e['full_name']}','subtitle':'Connected Buddy','target':5}),
      ...List<Map<String,dynamic>>.from(results[4]).map((e) => {'type':'Shared Desk','title':'${e['name']}','subtitle':'${e['type']} · ${e['role']}','target':6}),
    ];
    final controller = TextEditingController(); String query = '';
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) {
      final shown = all.where((e) => ('${e['title']} ${e['subtitle']} ${e['type']}').toLowerCase().contains(query.toLowerCase())).take(20).toList();
      return AlertDialog(
        title: const Text('Search myDesk'),
        content: SizedBox(width: 620, height: 460, child: Column(children: [
          TextField(controller: controller, autofocus: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search documents, tasks, bills, Buddies and desks'), onChanged: (v) => setLocal(() => query = v)),
          const SizedBox(height: 12),
          Expanded(child: shown.isEmpty ? const Center(child: Text('No matching items')) : ListView.separated(itemCount: shown.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final e = shown[i]; return ListTile(leading: CircleAvatar(child: Text('${e['type']}'[0])), title: Text('${e['title']}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${e['type']} · ${e['subtitle']}'), onTap: () { Navigator.pop(context); widget.onNavigate(e['target'] as int); }); })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
    }));
    controller.dispose();
  }

  @override Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: ListView(padding: const EdgeInsets.all(24), children: [
      FutureBuilder<Map<String,dynamic>?>(future: _profile, builder: (context, snap) {
        final name = snap.data?['full_name']?.toString().trim(); final first = (name == null || name.isEmpty) ? 'there' : name.split(RegExp(r'\s+')).first;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hello, $first 👋', style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.6)), const SizedBox(height: 6), Text('Here’s what needs your attention today.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15))]);
      }),
      const SizedBox(height: 18),
      InkWell(borderRadius: BorderRadius.circular(16), onTap: _openSearch, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.search), const SizedBox(width: 10), Expanded(child: Text('Search across myDesk', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), const Text('⌘ / Ctrl + K', style: TextStyle(fontSize: 12))]))),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.upload_file, size: 18), label: const Text('Upload document'), onPressed: () => widget.onNavigate(1)),
        ActionChip(avatar: const Icon(Icons.assignment_add, size: 18), label: const Text('Assign task'), onPressed: () => widget.onNavigate(3)),
        ActionChip(avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18), label: const Text('Open Khata'), onPressed: () => widget.onNavigate(4)),
        ActionChip(avatar: const Icon(Icons.groups_outlined, size: 18), label: const Text('Shared Desks'), onPressed: () => widget.onNavigate(6)),
      ]),
      const SizedBox(height: 24),
      FutureBuilder<Map<String,dynamic>>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
        if (snapshot.hasError) return Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [const Icon(Icons.cloud_off_outlined, size: 42), const SizedBox(height: 10), const Text('Could not load your dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('${snapshot.error}', textAlign: TextAlign.center), const SizedBox(height: 14), OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Try again'))])));
        final data = snapshot.data!;
        final overdue = List<Map<String,dynamic>>.from(data['overdue_bills'] as List); final dueTasks = List<Map<String,dynamic>>.from(data['due_soon_tasks'] as List); final assigned = List<Map<String,dynamic>>.from(data['assigned_tasks'] as List); final expiring = List<Map<String,dynamic>>.from(data['expiring_documents'] as List);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) { final columns = constraints.maxWidth >= 900 ? 5 : constraints.maxWidth >= 560 ? 2 : 1; return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: columns == 1 ? 3.2 : 1.65, children: [
            _MetricCard(icon: Icons.folder_outlined, label: 'Documents', value: '${data['documents']}', onTap: () => widget.onNavigate(1)),
            _MetricCard(icon: Icons.receipt_long_outlined, label: 'Unpaid bills', value: '${data['unpaid_bills']}', onTap: () => widget.onNavigate(2)),
            _MetricCard(icon: Icons.task_alt_outlined, label: 'Pending tasks', value: '${data['pending_tasks']}', onTap: () => widget.onNavigate(3)),
            _MetricCard(icon: Icons.account_balance_wallet_outlined, label: 'Open Khata', value: '${data['open_khata']}', onTap: () => widget.onNavigate(4)),
            _MetricCard(icon: Icons.groups_outlined, label: 'Shared Desks', value: '${data['desks']}', onTap: () => widget.onNavigate(6)),
          ]); }),
          if (assigned.isNotEmpty) ...[const SizedBox(height: 28), Row(children: [const Expanded(child: Text('Assigned to you', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), TextButton(onPressed: () => widget.onNavigate(3), child: const Text('View all'))]), const SizedBox(height: 8), ...assigned.take(5).map((task) => _AttentionTile(icon: Icons.assignment_ind_outlined, title: '${task['title']}', subtitle: '${_status(task['status'])}${task['due_date'] != null ? ' · due ${_formatDate(task['due_date'])}' : ''}', action: 'Open task', onTap: () => widget.onNavigate(3)))],
          const SizedBox(height: 26), Row(children: [const Expanded(child: Text('Needs attention', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))), IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh))]), const SizedBox(height: 10),
          if (overdue.isEmpty && dueTasks.isEmpty && expiring.isEmpty) const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.check_circle_outline)), title: Text('You are caught up', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('No overdue bills, upcoming tasks, or documents expiring in the next 30 days.'))),
          ...overdue.take(4).map((bill) => _AttentionTile(icon: Icons.warning_amber_rounded, title: '${bill['title']}', subtitle: 'Bill overdue · Rs. ${bill['amount']} · due ${bill['due_date']}', action: 'View bills', onTap: () => widget.onNavigate(2))),
          ...dueTasks.take(4).map((task) => _AttentionTile(icon: Icons.schedule, title: '${task['title']}', subtitle: 'Task due soon · ${_formatDate(task['due_date'])}${task['assignee_name'] != null ? ' · ${task['assignee_name']}' : ''}', action: 'View tasks', onTap: () => widget.onNavigate(3))),
          ...expiring.take(4).map((doc) => _AttentionTile(icon: Icons.event_busy_outlined, title: '${doc['title']}', subtitle: 'Document expires ${_formatDate(doc['expires_at'])}', action: 'View document', onTap: () => widget.onNavigate(1))),
        ]);
      }),
      const SizedBox(height: 26),
      const Text('Recent activity', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
      FutureBuilder<List<Map<String,dynamic>>>(future: _activity, builder: (context, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No recent collaboration activity yet.')));
        return Card(child: Column(children: items.map((n) => ListTile(leading: CircleAvatar(child: Icon(_activityIcon('${n['kind']}'))), title: Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: (n['body'] ?? '').toString().isEmpty ? null : Text('${n['body']}'))).toList()));
      }),
    ]),
  );

  String _formatDate(dynamic value) { final parsed = DateTime.tryParse('${value ?? ''}'); if (parsed == null) return 'No due date'; final local = parsed.toLocal(); return '${local.year}-${local.month.toString().padLeft(2,'0')}-${local.day.toString().padLeft(2,'0')}'; }
  String _status(dynamic value) => '${value ?? 'pending'}'.replaceAll('_',' ');
  IconData _activityIcon(String kind) => kind == 'task' ? Icons.task_alt : kind == 'khata' ? Icons.account_balance_wallet_outlined : kind == 'document' ? Icons.description_outlined : Icons.notifications_none;
}

class _MetricCard extends StatelessWidget { final IconData icon; final String label; final String value; final VoidCallback onTap; const _MetricCard({required this.icon, required this.label, required this.value, required this.onTap}); @override Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon, color: Theme.of(context).colorScheme.primary)), const Spacer(), Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label)])))); }
class _AttentionTile extends StatelessWidget { final IconData icon; final String title; final String subtitle; final String action; final VoidCallback onTap; const _AttentionTile({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap}); @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: TextButton(onPressed: onTap, child: Text(action)), onTap: onTap)); }
