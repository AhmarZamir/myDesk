import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/workspace_service.dart';
import '../workspace/khata_screen.dart';

class EntityDetailScreen extends StatefulWidget {
  final String kind;
  final String entityId;
  final String? fallbackTitle;
  final String? fallbackBody;

  const EntityDetailScreen({
    super.key,
    required this.kind,
    required this.entityId,
    this.fallbackTitle,
    this.fallbackBody,
  });

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  final _service = WorkspaceService();
  late Future<_EntityResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EntityResult> _load() async {
    switch (widget.kind) {
      case 'document':
        final rows = await _service.documents();
        return _EntityResult(widget.kind, _find(rows));
      case 'bill':
        final rows = await _service.bills();
        return _EntityResult(widget.kind, _find(rows));
      case 'task':
        final rows = await _service.tasks();
        return _EntityResult(widget.kind, _find(rows));
      case 'khata':
        final rows = await _service.khataEntries();
        return _EntityResult(widget.kind, _find(rows));
      default:
        return _EntityResult(widget.kind, null);
    }
  }

  Map<String, dynamic>? _find(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if ('${row['id']}' == widget.entityId) return row;
    }
    return null;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openDocument(Map<String, dynamic> item) async {
    try {
      final url = await _service.documentUrl('${item['storage_path']}');
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _message('Could not open this document.');
    } catch (e) {
      if (mounted) _message('Could not open document: $e');
    }
  }

  Future<void> _openKhataLedger(Map<String, dynamic> entry) async {
    final buddies = await _service.buddies();
    if (!mounted) return;
    final createdByMe = entry['created_by'] == _service.currentUserId;
    final buddyId = createdByMe ? entry['buddy_user_id']?.toString() : entry['created_by']?.toString();
    Map<String, dynamic>? buddy;
    for (final row in buddies) {
      if ('${row['user_id']}' == buddyId) {
        buddy = row;
        break;
      }
    }
    if (buddy == null) {
      _message('This Khata Buddy is no longer available.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuddyLedgerScreen(buddy: buddy!, readOnly: !createdByMe)),
    );
    _reload();
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle(), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<_EntityResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _MissingState(title: 'Could not load item', message: '${snapshot.error}');
          final result = snapshot.data!;
          final item = result.item;
          if (item == null) {
            return _MissingState(
              title: widget.fallbackTitle ?? 'Item unavailable',
              message: widget.fallbackBody ?? 'This item may have been removed or you may no longer have access.',
            );
          }
          if (result.kind == 'document') return _document(item);
          if (result.kind == 'bill') return _bill(item);
          if (result.kind == 'task') return _task(item);
          if (result.kind == 'khata') return _khata(item);
          return _MissingState(title: widget.fallbackTitle ?? 'Activity', message: widget.fallbackBody ?? 'No additional details are available.');
        },
      ),
    );
  }

  String _pageTitle() {
    switch (widget.kind) {
      case 'document': return 'Document';
      case 'bill': return 'Bill';
      case 'task': return 'Task';
      case 'khata': return 'Khata entry';
      default: return 'Activity';
    }
  }

  Widget _document(Map<String, dynamic> item) => _DetailBody(
        icon: Icons.description_outlined,
        title: '${item['title']}',
        rows: [
          ('Category', '${item['category']}'),
          ('Access', _visibility('${item['visibility']}')),
          if (item['expires_at'] != null) ('Expires', '${item['expires_at']}'),
        ],
        actions: [FilledButton.icon(onPressed: () => _openDocument(item), icon: const Icon(Icons.open_in_new), label: const Text('Open document'))],
      );

  Widget _bill(Map<String, dynamic> item) {
    final status = '${item['status']}';
    return _DetailBody(
      icon: status == 'paid' ? Icons.check_circle : Icons.receipt_long_outlined,
      title: '${item['title']}',
      rows: [
        ('Amount', 'Rs. ${item['amount']}'),
        ('Status', status),
        if (item['due_date'] != null) ('Due', '${item['due_date']}'),
        if (item['assignee_name'] != null) ('Responsible', '${item['assignee_name']}'),
      ],
      actions: [
        if (status != 'paid') FilledButton.icon(onPressed: () async { await _service.setBillStatus('${item['id']}', 'paid'); _reload(); }, icon: const Icon(Icons.check), label: const Text('Mark paid')),
      ],
    );
  }

  Widget _task(Map<String, dynamic> item) {
    final status = '${item['status']}';
    return _DetailBody(
      icon: status == 'completed' ? Icons.check_circle : Icons.task_alt,
      title: '${item['title']}',
      description: (item['description'] ?? '').toString().trim().isEmpty ? null : '${item['description']}',
      rows: [
        ('Status', status.replaceAll('_', ' ')),
        ('Priority', '${item['priority']}'),
        if (item['due_date'] != null) ('Due', '${item['due_date']}'),
        if (item['assignee_name'] != null) ('Assigned to', '${item['assignee_name']}'),
      ],
      actions: [
        if (status != 'completed') FilledButton.icon(onPressed: () async { await _service.setTaskStatus('${item['id']}', 'completed'); _reload(); }, icon: const Icon(Icons.task_alt), label: const Text('Mark completed')),
        if (status == 'pending') OutlinedButton.icon(onPressed: () async { await _service.setTaskStatus('${item['id']}', 'in_progress'); _reload(); }, icon: const Icon(Icons.play_arrow), label: const Text('Start task')),
      ],
    );
  }

  Widget _khata(Map<String, dynamic> item) {
    final mine = item['created_by'] == _service.currentUserId;
    final creatorReceivable = item['direction'] == 'receivable';
    final incoming = mine ? creatorReceivable : !creatorReceivable;
    return _DetailBody(
      icon: incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
      title: incoming ? 'Inflow · Rs. ${item['amount']}' : 'Outflow · Rs. ${item['amount']}',
      description: (item['note'] ?? '').toString().trim().isEmpty ? null : '${item['note']}',
      rows: [
        ('Status', '${item['status']}'),
        ('Person', '${item['counterparty_name']}'),
        ('Perspective', incoming ? 'Money to receive' : 'Money to give'),
      ],
      actions: [FilledButton.icon(onPressed: () => _openKhataLedger(item), icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Open Buddy ledger'))],
    );
  }

  String _visibility(String value) => value == 'desk' ? 'Whole desk' : value == 'custom' ? 'Selected Buddies' : 'Only me';
}

class _EntityResult {
  final String kind;
  final Map<String, dynamic>? item;
  const _EntityResult(this.kind, this.item);
}

class _DetailBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final List<(String, String)> rows;
  final List<Widget> actions;

  const _DetailBody({required this.icon, required this.title, this.description, required this.rows, required this.actions});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 26, child: Icon(icon)),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                if (description != null) ...[const SizedBox(height: 8), Text(description!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))],
                const SizedBox(height: 22),
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 120, child: Text(row.$1, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        Expanded(child: Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w700))),
                      ]),
                    )),
                if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 10, children: actions)],
              ]),
            ),
          ),
        ],
      );
}

class _MissingState extends StatelessWidget {
  final String title;
  final String message;
  const _MissingState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, size: 44),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ]))),
          ),
        ),
      );
}
