import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = WorkspaceService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.dashboardSnapshot();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.dashboardSnapshot());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Your Desk', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('A live view of what you own, what is assigned to you, and what needs attention.'),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 10),
                      const Text('Could not load your dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Try again')),
                    ]),
                  ),
                );
              }

              final data = snapshot.data!;
              final overdue = List<Map<String, dynamic>>.from(data['overdue_bills'] as List);
              final dueTasks = List<Map<String, dynamic>>.from(data['due_soon_tasks'] as List);
              final expiring = List<Map<String, dynamic>>.from(data['expiring_documents'] as List);

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 5 : constraints.maxWidth >= 560 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.2 : 1.65,
                    children: [
                      _MetricCard(icon: Icons.folder_outlined, label: 'Documents', value: '${data['documents']}', onTap: () => widget.onNavigate(1)),
                      _MetricCard(icon: Icons.receipt_long_outlined, label: 'Unpaid bills', value: '${data['unpaid_bills']}', onTap: () => widget.onNavigate(2)),
                      _MetricCard(icon: Icons.task_alt_outlined, label: 'Pending tasks', value: '${data['pending_tasks']}', onTap: () => widget.onNavigate(3)),
                      _MetricCard(icon: Icons.account_balance_wallet_outlined, label: 'Open Khata', value: '${data['open_khata']}', onTap: () => widget.onNavigate(4)),
                      _MetricCard(icon: Icons.groups_outlined, label: 'Shared Desks', value: '${data['desks']}', onTap: () => widget.onNavigate(5)),
                    ],
                  );
                }),
                const SizedBox(height: 26),
                Row(children: [
                  const Expanded(child: Text('Needs attention', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
                ]),
                const SizedBox(height: 10),
                if (overdue.isEmpty && dueTasks.isEmpty && expiring.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.check_circle_outline)),
                      title: Text('You are caught up', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('No overdue bills, upcoming tasks, or documents expiring in the next 30 days.'),
                    ),
                  ),
                ...overdue.take(4).map((bill) => _AttentionTile(
                      icon: Icons.warning_amber_rounded,
                      title: '${bill['title']}',
                      subtitle: 'Bill overdue · Rs. ${bill['amount']} · due ${bill['due_date']}',
                      action: 'View bills',
                      onTap: () => widget.onNavigate(2),
                    )),
                ...dueTasks.take(4).map((task) => _AttentionTile(
                      icon: Icons.schedule,
                      title: '${task['title']}',
                      subtitle: 'Task due soon · ${_formatDate(task['due_date'])}${task['assignee_name'] != null ? ' · ${task['assignee_name']}' : ''}',
                      action: 'View tasks',
                      onTap: () => widget.onNavigate(3),
                    )),
                ...expiring.take(4).map((doc) => _AttentionTile(
                      icon: Icons.event_busy_outlined,
                      title: '${doc['title']}',
                      subtitle: 'Document expires ${_formatDate(doc['expires_at'])}',
                      action: 'View document',
                      onTap: () => widget.onNavigate(1),
                    )),
              ]);
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return 'No due date';
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label),
          ]),
        ),
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  const _AttentionTile({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onTap, child: Text(action)),
        onTap: onTap,
      ),
    );
  }
}
