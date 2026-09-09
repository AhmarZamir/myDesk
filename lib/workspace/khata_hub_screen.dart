import 'package:flutter/material.dart';
import '../core/app_semantics.dart';
import '../services/workspace_service.dart';
import 'khata_screen.dart';

class KhataHubScreen extends StatefulWidget {
  const KhataHubScreen({super.key});
  @override State<KhataHubScreen> createState() => _KhataHubScreenState();
}

class _KhataHubScreenState extends State<KhataHubScreen> {
  final _service = WorkspaceService();
  late Future<List<Map<String,dynamic>>> _future;
  @override void initState() { super.initState(); _future = _service.khataEntries(); }

  @override Widget build(BuildContext context) => Column(children: [
    FutureBuilder<List<Map<String,dynamic>>>(future: _future, builder: (context, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      double receive = 0, give = 0;
      for (final item in snap.data!.where((e) => e['status'] != 'settled')) {
        final mine = item['created_by'] == _service.currentUserId;
        final creatorReceivable = item['direction'] == 'receivable';
        final receivableForMe = mine ? creatorReceivable : !creatorReceivable;
        final value = double.tryParse('${item['amount']}') ?? 0;
        if (receivableForMe) receive += value; else give += value;
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final take = _BalanceCard(label: 'Total you have to take', amount: receive, icon: Icons.south_west_rounded, color: AppSemantics.incoming);
          final giveCard = _BalanceCard(label: 'Total you have to give', amount: give, icon: Icons.north_east_rounded, color: AppSemantics.outgoing);
          if (compact) {
            return Column(children: [SizedBox(height: 105, child: take), const SizedBox(height: 10), SizedBox(height: 105, child: giveCard)]);
          }
          return SizedBox(height: 112, child: Row(children: [Expanded(child: take), const SizedBox(width: 12), Expanded(child: giveCard)]));
        }),
      );
    }),
    const Expanded(child: BuddyKhataScreen()),
  ]);
}

class _BalanceCard extends StatelessWidget {
  final String label; final double amount; final IconData icon; final Color color;
  const _BalanceCard({required this.label, required this.amount, required this.icon, required this.color});
  @override Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {},
      child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        CircleAvatar(backgroundColor: AppSemantics.soft(color), child: Icon(icon, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text('Rs. ${amount.toStringAsFixed(2)}', key: ValueKey(amount), style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: color)),
          ),
        ])),
      ])),
    ),
  );
}
