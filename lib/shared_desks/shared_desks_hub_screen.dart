import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/desk_service.dart';
import '../services/workspace_service.dart';
import '../services/buddy_service.dart';

class SharedDesksHubScreen extends StatefulWidget {
  const SharedDesksHubScreen({super.key});
  @override State<SharedDesksHubScreen> createState() => _SharedDesksHubScreenState();
}

class _SharedDesksHubScreenState extends State<SharedDesksHubScreen> {
  final _desks = DeskService();
  final _workspace = WorkspaceService();
  late Future<List<dynamic>> _future;

  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = Future.wait([_desks.fetchMyDesks(), _workspace.documents(), _workspace.bills(), _workspace.tasks()]);
  void _refresh() => setState(_reload);

  Future<void> _create() async {
    final name = TextEditingController(); String type = 'family';
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Create Shared Desk'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Desk name')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Type'), items: const ['family','business','roommates','custom'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setLocal(() => type = v ?? 'custom')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (name.text.trim().length < 2) return; Navigator.pop(context, true); }, child: const Text('Create'))],
    )));
    if (ok == true) { try { await _desks.createDesk(name: name.text, type: type); _refresh(); } catch (e) { _message('Could not create desk: $e'); } }
    name.dispose();
  }

  Future<void> _join() async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Join Shared Desk'), content: TextField(controller: code, autofocus: true, decoration: const InputDecoration(labelText: 'Invite code')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () { if (code.text.trim().isNotEmpty) Navigator.pop(context, true); }, child: const Text('Join'))],
    ));
    if (ok == true) { try { await _desks.joinDesk(code.text); _refresh(); } catch (e) { _message('Could not join desk: $e'); } }
    code.dispose();
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
    Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Shared Desks', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5), Text('Each space has its own people, documents, bills and tasks.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      Wrap(spacing: 8, children: [OutlinedButton.icon(onPressed: _join, icon: const Icon(Icons.login), label: const Text('Join desk')), FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Create desk'))]),
    ]),
    const SizedBox(height: 22),
    FutureBuilder<List<dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
      if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load Shared Desks: ${snap.error}')));
      final desks = List<Map<String,dynamic>>.from(snap.data![0] as List);
      final docs = List<Map<String,dynamic>>.from(snap.data![1] as List);
      final bills = List<Map<String,dynamic>>.from(snap.data![2] as List);
      final tasks = List<Map<String,dynamic>>.from(snap.data![3] as List);
      if (desks.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(36), child: Center(child: Text('No Shared Desks yet.'))));
      return LayoutBuilder(builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
        return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: desks.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: cols == 1 ? 2.8 : 1.28), itemBuilder: (context, i) {
          final d = desks[i]; final id = '${d['id']}';
          final dDocs = docs.where((e) => '${e['desk_id']}' == id).length;
          final dBills = bills.where((e) => '${e['desk_id']}' == id && e['status'] != 'paid').length;
          final dTasks = tasks.where((e) => '${e['desk_id']}' == id && e['status'] != 'completed').length;
          return Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => SharedDeskDashboard(desk: d))); _refresh(); }, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [CircleAvatar(child: Icon(_deskIcon('${d['type']}'))), const Spacer(), Chip(label: Text('${d['role']}')), const Icon(Icons.chevron_right)]),
            const Spacer(), Text('${d['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4), Text('${d['type']} workspace', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14), Row(children: [Expanded(child: _MiniStat(icon: Icons.description_outlined, value: dDocs, label: 'Files')), Expanded(child: _MiniStat(icon: Icons.receipt_long_outlined, value: dBills, label: 'Bills')), Expanded(child: _MiniStat(icon: Icons.task_alt, value: dTasks, label: 'Tasks'))]),
          ]))));
        });
      });
    }),
  ]);
}

class SharedDeskDashboard extends StatefulWidget {
  final Map<String,dynamic> desk;
  const SharedDeskDashboard({super.key, required this.desk});
  @override State<SharedDeskDashboard> createState() => _SharedDeskDashboardState();
}

class _SharedDeskDashboardState extends State<SharedDeskDashboard> {
  final _deskService = DeskService();
  final _workspace = WorkspaceService();
  final _buddyService = BuddyService();
  late Future<List<dynamic>> _future;
  String section = 'overview';
  String get id => '${widget.desk['id']}';

  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = Future.wait([_deskService.fetchDeskMembers(id), _workspace.documents(), _workspace.bills(), _workspace.tasks(), _buddyService.buddies()]);
  void _refresh() => setState(_reload);

  Future<void> _memberAction(Map<String,dynamic> member, String action) async {
    try {
      if (action == 'remove') await _deskService.removeMember(deskId: id, userId: '${member['user_id']}');
      else await _deskService.setMemberRole(deskId: id, userId: '${member['user_id']}', role: action);
      _refresh();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update member: $e'))); }
  }

  Future<void> _addBuddy(Map<String,dynamic> member) async {
    try {
      await _buddyService.addSharedDeskMemberAsBuddy(deskId: id, userId: '${member['user_id']}');
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member['full_name']} added to your Buddies.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add Buddy: $e')));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.desk['name']}', style: const TextStyle(fontWeight: FontWeight.w900)), actions: [if ((widget.desk['invite_code'] ?? '').toString().isNotEmpty) IconButton(tooltip: 'Copy invite code', icon: const Icon(Icons.link), onPressed: () async { await Clipboard.setData(ClipboardData(text: '${widget.desk['invite_code']}')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied.'))); })]),
    body: FutureBuilder<List<dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) return Center(child: Text('Could not load desk: ${snap.error}'));
      final members = List<Map<String,dynamic>>.from(snap.data![0] as List);
      final docs = List<Map<String,dynamic>>.from(snap.data![1] as List).where((e) => '${e['desk_id']}' == id).toList();
      final bills = List<Map<String,dynamic>>.from(snap.data![2] as List).where((e) => '${e['desk_id']}' == id).toList();
      final tasks = List<Map<String,dynamic>>.from(snap.data![3] as List).where((e) => '${e['desk_id']}' == id).toList();
      final buddies = List<Map<String,dynamic>>.from(snap.data![4] as List);
      final buddyIds = buddies.map((b) => '${b['user_id']}').toSet();
      final openBills = bills.where((e) => e['status'] != 'paid').length;
      final openTasks = tasks.where((e) => e['status'] != 'completed').length;
      return ListView(padding: const EdgeInsets.all(24), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Wrap(spacing: 20, runSpacing: 16, children: [
          _LargeStat(icon: Icons.people_outline, value: members.length, label: 'Members'), _LargeStat(icon: Icons.description_outlined, value: docs.length, label: 'Documents'), _LargeStat(icon: Icons.receipt_long_outlined, value: openBills, label: 'Open bills'), _LargeStat(icon: Icons.task_alt, value: openTasks, label: 'Tasks to do'),
        ]))),
        const SizedBox(height: 16),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Wrap(spacing: 8, children: {'overview':'Overview','members':'Members','documents':'Documents','bills':'Bills','tasks':'Tasks'}.entries.map((e) => ChoiceChip(label: Text(e.value), selected: section == e.key, onSelected: (_) => setState(() => section = e.key))).toList())),
        const SizedBox(height: 18),
        if (section == 'overview') ...[
          _Section(title: 'Tasks to be done', items: tasks.where((e) => e['status'] != 'completed').take(5).map((e) => ListTile(leading: const Icon(Icons.task_alt), title: Text('${e['title']}'), subtitle: Text('${e['status']} · ${e['assignee_name'] ?? 'Unassigned'}'))).toList()),
          _Section(title: 'Recently shared content', items: docs.take(5).map((e) => ListTile(leading: const Icon(Icons.description_outlined), title: Text('${e['title']}'), subtitle: Text('${e['category']} · ${e['visibility']}'))).toList()),
        ],
        if (section == 'members') ...members.map((m) {
          final role = '${m['role']}';
          final isMe = m['is_me'] == true;
          final isBuddy = buddyIds.contains('${m['user_id']}');
          final canManage = widget.desk['role'] == 'owner' || widget.desk['role'] == 'admin';
          return Card(child: ListTile(
            leading: _Avatar(name: '${m['full_name']}', url: m['avatar_url']?.toString()),
            title: Text('${m['full_name']}${isMe ? ' (You)' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(isMe ? role : isBuddy ? '$role · Buddy' : '$role · Shared Desk member'),
            trailing: isMe ? null : Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (!isBuddy) IconButton(tooltip: 'Add as Buddy', icon: const Icon(Icons.person_add_alt_1), onPressed: () => _addBuddy(m)),
              if (isBuddy) const Tooltip(message: 'Already a Buddy', child: Icon(Icons.people_alt_outlined)),
              if (canManage && role != 'owner') PopupMenuButton<String>(onSelected: (v) => _memberAction(m, v), itemBuilder: (_) => [if (widget.desk['role'] == 'owner') ...const [PopupMenuItem(value: 'admin', child: Text('Make admin')), PopupMenuItem(value: 'member', child: Text('Make member')), PopupMenuItem(value: 'viewer', child: Text('Make viewer'))], const PopupMenuItem(value: 'remove', child: Text('Remove member'))]),
            ]),
          ));
        }),
        if (section == 'documents') ..._simpleCards(docs, Icons.description_outlined, (e) => '${e['title']}', (e) => '${e['category']} · ${e['visibility']}'),
        if (section == 'bills') ..._simpleCards(bills, Icons.receipt_long_outlined, (e) => '${e['title']} · Rs. ${e['amount']}', (e) => '${e['status']}${e['due_date'] != null ? ' · due ${e['due_date']}' : ''}'),
        if (section == 'tasks') ..._simpleCards(tasks, Icons.task_alt, (e) => '${e['title']}', (e) => '${e['status']} · ${e['priority']} priority · ${e['assignee_name'] ?? 'Unassigned'}'),
      ]);
    }),
  );

  List<Widget> _simpleCards(List<Map<String,dynamic>> rows, IconData icon, String Function(Map<String,dynamic>) title, String Function(Map<String,dynamic>) subtitle) => rows.isEmpty ? [const Card(child: Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Nothing here yet.'))))] : rows.map((e) => Card(child: ListTile(leading: Icon(icon), title: Text(title(e), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle(e))))).toList();
}

class _MiniStat extends StatelessWidget { final IconData icon; final int value; final String label; const _MiniStat({required this.icon, required this.value, required this.label}); @override Widget build(BuildContext context) => Column(children: [Icon(icon, size: 18), const SizedBox(height: 4), Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 11))]); }
class _LargeStat extends StatelessWidget { final IconData icon; final int value; final String label; const _LargeStat({required this.icon, required this.value, required this.label}); @override Widget build(BuildContext context) => SizedBox(width: 150, child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(label)])])); }
class _Section extends StatelessWidget { final String title; final List<Widget> items; const _Section({required this.title, required this.items}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('Nothing here yet.'))) else Card(child: Column(children: items))])); }
class _Avatar extends StatelessWidget { final String name; final String? url; const _Avatar({required this.name, this.url}); @override Widget build(BuildContext context) { if (url != null && url!.isNotEmpty) return CircleAvatar(backgroundImage: NetworkImage(url!)); return CircleAvatar(child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase())); } }
IconData _deskIcon(String type) => type == 'family' ? Icons.family_restroom : type == 'business' ? Icons.business_center_outlined : type == 'roommates' ? Icons.home_outlined : Icons.groups_outlined;
