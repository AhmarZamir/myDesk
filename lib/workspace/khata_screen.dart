import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class BuddyKhataScreen extends StatefulWidget {
  const BuddyKhataScreen({super.key});

  @override
  State<BuddyKhataScreen> createState() => _BuddyKhataScreenState();
}

class _BuddyKhataScreenState extends State<BuddyKhataScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> _buddies;
  late Future<List<Map<String, dynamic>>> _entries;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _buddies = service.buddies();
    _entries = service.khataEntries();
  }

  void _refresh() => setState(_reload);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Khata', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(
          _tab == 0
              ? 'Customers are Khata accounts you manage with your Buddies.'
              : 'Community shows Khata accounts your Buddies shared with you. These ledgers are read-only.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.person_outline), label: Text('Customers')),
            ButtonSegment(value: 1, icon: Icon(Icons.groups_outlined), label: Text('Community')),
          ],
          selected: {_tab},
          onSelectionChanged: (value) => setState(() => _tab = value.first),
        ),
        const SizedBox(height: 24),
        FutureBuilder<List<dynamic>>(
          future: Future.wait([_buddies, _entries]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load Khata: ${snapshot.error}')));
            }

            final buddies = List<Map<String, dynamic>>.from(snapshot.data![0] as List);
            final entries = List<Map<String, dynamic>>.from(snapshot.data![1] as List);

            return _tab == 0
                ? _CustomersView(
                    service: service,
                    buddies: buddies,
                    entries: entries,
                    onChanged: _refresh,
                  )
                : _CommunityView(
                    service: service,
                    buddies: buddies,
                    entries: entries,
                  );
          },
        ),
      ],
    );
  }
}

class _CustomersView extends StatelessWidget {
  final WorkspaceService service;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> entries;
  final VoidCallback onChanged;

  const _CustomersView({
    required this.service,
    required this.buddies,
    required this.entries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (buddies.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(34),
          child: Column(children: [
            Icon(Icons.people_outline, size: 46),
            SizedBox(height: 12),
            Text('No Buddy customers yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Add a Buddy first. You can then maintain a separate Khata account for that person.', textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    final myEntries = entries.where((e) => e['created_by'] == service.currentUserId).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: buddies.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.3 : 1.55,
        ),
        itemBuilder: (context, index) {
          final buddy = buddies[index];
          final buddyId = buddy['user_id'] as String;
          final buddyEntries = myEntries.where((e) => e['buddy_user_id'] == buddyId).toList();
          final net = _netForCurrentUser(service, buddyEntries);

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BuddyLedgerScreen(buddy: buddy, readOnly: false)),
                );
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _BuddyAvatar(name: '${buddy['full_name']}', url: buddy['avatar_url']?.toString()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${buddy['full_name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Your Khata · ${buddyEntries.length} ${buddyEntries.length == 1 ? 'entry' : 'entries'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                  const Spacer(),
                  Text(_netLabel(net, buddy['full_name']?.toString() ?? 'Buddy'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Rs. ${net.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: net == 0 ? null : Theme.of(context).colorScheme.primary)),
                ]),
              ),
            ),
          );
        },
      );
    });
  }
}

class _CommunityView extends StatelessWidget {
  final WorkspaceService service;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> entries;

  const _CommunityView({required this.service, required this.buddies, required this.entries});

  @override
  Widget build(BuildContext context) {
    final sharedEntries = entries.where((e) => e['created_by'] != service.currentUserId && e['buddy_user_id'] == service.currentUserId).toList();
    final creatorIds = sharedEntries.map((e) => e['created_by']?.toString()).whereType<String>().toSet();
    final sharedBuddies = buddies.where((b) => creatorIds.contains(b['user_id']?.toString())).toList();

    if (sharedBuddies.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(34),
          child: Column(children: [
            Icon(Icons.groups_outlined, size: 46),
            SizedBox(height: 12),
            Text('Nothing shared with you yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('When a Buddy creates a Khata account with you, it will appear here as a read-only community ledger.', textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sharedBuddies.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.3 : 1.55,
        ),
        itemBuilder: (context, index) {
          final buddy = sharedBuddies[index];
          final buddyId = buddy['user_id'] as String;
          final buddyEntries = sharedEntries.where((e) => e['created_by'] == buddyId).toList();
          final net = _netForCurrentUser(service, buddyEntries);
          final name = buddy['full_name']?.toString() ?? 'Buddy';

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BuddyLedgerScreen(buddy: buddy, readOnly: true)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _BuddyAvatar(name: name, url: buddy['avatar_url']?.toString()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Shared with you · read-only', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                    const Icon(Icons.visibility_outlined),
                  ]),
                  const Spacer(),
                  Text(_netLabel(net, name), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Rs. ${net.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: net == 0 ? null : Theme.of(context).colorScheme.primary)),
                ]),
              ),
            ),
          );
        },
      );
    });
  }
}

class BuddyLedgerScreen extends StatefulWidget {
  final Map<String, dynamic> buddy;
  final bool readOnly;
  const BuddyLedgerScreen({super.key, required this.buddy, required this.readOnly});

  @override
  State<BuddyLedgerScreen> createState() => _BuddyLedgerScreenState();
}

class _BuddyLedgerScreenState extends State<BuddyLedgerScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> _future;

  String get buddyId => widget.buddy['user_id'] as String;
  String get buddyName => '${widget.buddy['full_name']}';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = service.khataEntries());

  Future<void> _add() async {
    if (widget.readOnly) return;
    final amount = TextEditingController();
    final note = TextEditingController();
    bool theyOweMe = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('New entry with $buddyName'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, icon: Icon(Icons.south_west), label: Text('They owe me')),
                  ButtonSegment(value: false, icon: Icon(Icons.north_east), label: Text('I owe them')),
                ],
                selected: {theyOweMe},
                onSelectionChanged: (v) => setLocal(() => theyOweMe = v.first),
              ),
              const SizedBox(height: 16),
              TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. ')),
              const SizedBox(height: 12),
              TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 10),
              Text('$buddyName will see the same entry in read-only mode from their own perspective.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amount.text.trim());
                if (value == null || value <= 0) return;
                Navigator.pop(context, true);
              },
              child: const Text('Add entry'),
            ),
          ],
        ),
      ),
    );

    final value = double.tryParse(amount.text.trim());
    if (ok == true && value != null) {
      try {
        await service.addKhataEntry(amount: value, note: note.text, counterpartyName: buddyName, theyOweMe: theyOweMe, buddyUserId: buddyId);
        _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add entry: $e')));
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<bool> _confirmDelete() async => await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete entry?'),
          content: const Text('This removes the entry from both sides of the shared ledger.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      ) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          _BuddyAvatar(name: buddyName, url: widget.buddy['avatar_url']?.toString(), radius: 16),
          const SizedBox(width: 10),
          Expanded(child: Text('$buddyName · Khata', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
      floatingActionButton: widget.readOnly ? null : FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add entry')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Could not load ledger: ${snapshot.error}'));

          final all = snapshot.data ?? [];
          final items = widget.readOnly
              ? all.where((e) => e['created_by'] == buddyId && e['buddy_user_id'] == service.currentUserId).toList()
              : all.where((e) => e['created_by'] == service.currentUserId && e['buddy_user_id'] == buddyId).toList();

          double receivable = 0;
          double payable = 0;
          for (final item in items.where((e) => e['status'] != 'settled')) {
            final mine = item['created_by'] == service.currentUserId;
            final creatorReceivable = item['direction'] == 'receivable';
            final receivableForMe = mine ? creatorReceivable : !creatorReceivable;
            final value = double.tryParse('${item['amount']}') ?? 0;
            if (receivableForMe) receivable += value; else payable += value;
          }
          final net = receivable - payable;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            children: [
              if (widget.readOnly)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 10),
                    Expanded(child: Text('Community ledger · read-only. Only the Buddy who owns this Khata can edit, settle, or delete entries.')),
                  ]),
                ),
              _NetBalanceBar(buddyName: buddyName, net: net),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Expanded(child: _Summary(label: '$buddyName owes you', value: receivable)),
                    Container(width: 1, height: 46, color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(width: 18),
                    Expanded(child: _Summary(label: 'You owe $buddyName', value: payable)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.readOnly ? 'Shared transactions' : 'Transactions', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (items.isEmpty)
                Card(child: Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(widget.readOnly ? 'No shared transactions from this Buddy yet.' : 'No transactions with this Buddy yet.')))),
              ...items.map((item) {
                final mine = item['created_by'] == service.currentUserId;
                final creatorReceivable = item['direction'] == 'receivable';
                final receivableForMe = mine ? creatorReceivable : !creatorReceivable;
                final settled = item['status'] == 'settled';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(receivableForMe ? Icons.south_west : Icons.north_east)),
                    title: Text(receivableForMe ? 'Inflow' : 'Outflow', style: TextStyle(fontWeight: FontWeight.w800, decoration: settled ? TextDecoration.lineThrough : null)),
                    subtitle: Text([
                      receivableForMe ? '$buddyName owes you' : 'You owe $buddyName',
                      settled ? 'settled' : 'open',
                      if (widget.readOnly) 'Added by $buddyName · read-only',
                      if ((item['note'] ?? '').toString().trim().isNotEmpty) '${item['note']}',
                    ].join(' · ')),
                    trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('${receivableForMe ? '+' : '-'} Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (!widget.readOnly && mine)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'settle') await service.settleKhata(item['id']);
                            if (value == 'delete' && await _confirmDelete()) await service.deleteKhata(item['id']);
                            _refresh();
                          },
                          itemBuilder: (_) => [
                            if (!settled) const PopupMenuItem(value: 'settle', child: Text('Mark settled')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ]),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

double _netForCurrentUser(WorkspaceService service, List<Map<String, dynamic>> items) {
  double receivable = 0;
  double payable = 0;
  for (final item in items.where((e) => e['status'] != 'settled')) {
    final mine = item['created_by'] == service.currentUserId;
    final creatorReceivable = item['direction'] == 'receivable';
    final receivableForMe = mine ? creatorReceivable : !creatorReceivable;
    final value = double.tryParse('${item['amount']}') ?? 0;
    if (receivableForMe) receivable += value; else payable += value;
  }
  return receivable - payable;
}

String _netLabel(double net, String buddyName) {
  if (net > 0) return '$buddyName owes you';
  if (net < 0) return 'You owe $buddyName';
  return 'Settled';
}

class _NetBalanceBar extends StatelessWidget {
  final String buddyName;
  final double net;
  const _NetBalanceBar({required this.buddyName, required this.net});

  @override
  Widget build(BuildContext context) {
    final settled = net.abs() < 0.005;
    final positive = net > 0;
    final icon = settled ? Icons.check_circle_outline : positive ? Icons.call_received_rounded : Icons.call_made_rounded;
    final message = settled
        ? 'Settled — balance is Rs. 0.00'
        : positive
            ? '$buddyName owes you Rs. ${net.abs().toStringAsFixed(2)}'
            : 'You owe $buddyName Rs. ${net.abs().toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: settled ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: settled ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.primary.withValues(alpha: .45)),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: settled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.primary,
          child: Icon(icon, color: settled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _BuddyAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const _BuddyAvatar({required this.name, this.url, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url!), backgroundColor: const Color(0xFF10192B));
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(radius: radius, child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)));
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final double value;
  const _Summary({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        Text('Rs. ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ]);
}
