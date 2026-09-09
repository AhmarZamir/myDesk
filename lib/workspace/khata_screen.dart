import 'package:flutter/material.dart';
import '../services/workspace_service.dart';

class BuddyKhataScreen extends StatefulWidget {
  const BuddyKhataScreen({super.key});

  @override
  State<BuddyKhataScreen> createState() => _BuddyKhataScreenState();
}

class _BuddyKhataScreenState extends State<BuddyKhataScreen> {
  final service = WorkspaceService();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = service.khataEntries();
  }

  void refresh() => setState(() => future = service.khataEntries());

  Future<void> add() async {
    final buddies = await service.buddies();
    if (!mounted) return;
    final person = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    String? buddyUserId;
    String? buddyName;
    bool theyOweMe = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Khata entry'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownButtonFormField<String?>(
                  initialValue: buddyUserId,
                  decoration: const InputDecoration(labelText: 'myDesk Buddy (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Manual / private person')),
                    ...buddies.map((b) => DropdownMenuItem<String?>(value: b['user_id'] as String, child: Text('${b['full_name']}'))),
                  ],
                  onChanged: (v) {
                    final match = buddies.where((b) => b['user_id'] == v).toList();
                    setLocal(() {
                      buddyUserId = v;
                      buddyName = match.isEmpty ? null : '${match.first['full_name']}';
                      if (buddyName != null) person.text = buddyName!;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  buddyUserId == null
                      ? 'A manual entry stays private to you.'
                      : '$buddyName will see this same entry in read-only mode from their own perspective.',
                ),
                const SizedBox(height: 12),
                if (buddyUserId == null)
                  TextField(controller: person, autofocus: true, decoration: const InputDecoration(labelText: 'Person name')),
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
          buddyUserId: buddyUserId,
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

  Future<bool> _confirmDelete() async => await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Khata entry?'),
          content: const Text('This removes the entry for both you and the Buddy who can currently view it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      ) ?? false;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Khata', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('Private notes or transparent read-only ledgers with your myDesk Buddies.'),
              ]),
              FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add entry')),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load Khata: ${snap.error}')));
              final items = snap.data ?? [];
              if (items.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(36), child: Center(child: Text('No Khata entries yet'))));

              double inflow = 0;
              double outflow = 0;
              for (final item in items.where((e) => e['status'] != 'settled')) {
                final mine = item['created_by'] == service.currentUserId;
                final creatorDirection = item['direction'] == 'receivable';
                final receivableForMe = mine ? creatorDirection : !creatorDirection;
                final value = double.tryParse('${item['amount']}') ?? 0;
                if (receivableForMe) inflow += value; else outflow += value;
              }

              return Column(children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Expanded(child: _Summary(label: 'You are owed', value: inflow)),
                      const SizedBox(width: 12),
                      Expanded(child: _Summary(label: 'You owe', value: outflow)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                ...items.map((item) {
                  final mine = item['created_by'] == service.currentUserId;
                  final creatorReceivable = item['direction'] == 'receivable';
                  final receivableForMe = mine ? creatorReceivable : !creatorReceivable;
                  final settled = item['status'] == 'settled';
                  final buddyName = item['buddy_name']?.toString();
                  final displayName = mine ? (buddyName ?? '${item['counterparty_name']}') : (buddyName ?? 'Buddy');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(receivableForMe ? Icons.south_west : Icons.north_east)),
                      title: Text(displayName, style: TextStyle(fontWeight: FontWeight.w700, decoration: settled ? TextDecoration.lineThrough : null)),
                      subtitle: Text([
                        receivableForMe ? 'They owe you' : 'You owe them',
                        settled ? 'settled' : 'open',
                        if (!mine) 'Shared by Buddy · read-only',
                        if (mine && item['buddy_user_id'] != null) 'Shared with Buddy',
                        if ((item['note'] ?? '').toString().trim().isNotEmpty) '${item['note']}',
                      ].join(' · ')),
                      trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('${receivableForMe ? '+' : '-'} Rs. ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (mine)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              try {
                                if (value == 'settle') await service.settleKhata(item['id']);
                                if (value == 'delete' && await _confirmDelete()) await service.deleteKhata(item['id']);
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
                }),
              ]);
            },
          ),
        ],
      );
}

class _Summary extends StatelessWidget {
  final String label;
  final double value;
  const _Summary({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label),
        const SizedBox(height: 4),
        Text('Rs. ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ]);
}
