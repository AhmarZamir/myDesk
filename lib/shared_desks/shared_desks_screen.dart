import 'package:flutter/material.dart';
import '../services/desk_service.dart';

class SharedDesksScreen extends StatefulWidget {
  const SharedDesksScreen({super.key});

  @override
  State<SharedDesksScreen> createState() => _SharedDesksScreenState();
}

class _SharedDesksScreenState extends State<SharedDesksScreen> {
  final _service = DeskService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => _future = _service.fetchMyDesks();

  Future<void> _reload() async {
    setState(_refresh);
    await _future;
  }

  Future<void> _createDesk() async {
    final name = TextEditingController();
    String type = 'family';
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Create a Shared Desk'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Desk name', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'family', child: Text('Family')),
                    DropdownMenuItem(value: 'business', child: Text('Business')),
                    DropdownMenuItem(value: 'roommates', child: Text('Roommates')),
                    DropdownMenuItem(value: 'custom', child: Text('Other')),
                  ],
                  onChanged: (value) => setLocalState(() => type = value ?? 'custom'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().length < 2) return;
                try {
                  await _service.createDesk(name: name.text, type: type);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create desk: $e')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (created == true) await _reload();
  }

  Future<void> _joinDesk() async {
    final code = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a Shared Desk'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. A1B2C3D4', border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (code.text.trim().isEmpty) return;
              try {
                await _service.joinDesk(code.text);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not join desk: $e')));
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
    code.dispose();
    if (joined == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shared Desks', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text('Family, business and trusted groups in one private workspace.', style: TextStyle(color: Colors.black54)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(onPressed: _joinDesk, icon: const Icon(Icons.login), label: const Text('Join desk')),
                  FilledButton.icon(onPressed: _createDesk, icon: const Icon(Icons.add), label: const Text('Create desk')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return _MessageCard(icon: Icons.cloud_off, title: 'Could not load desks', message: '${snapshot.error}');
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const _MessageCard(
                  icon: Icons.groups_2_outlined,
                  title: 'No Shared Desks yet',
                  message: 'Create a Family Desk or join someone using their invite code.',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 950 ? 3 : width >= 600 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.7,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final membership = rows[index];
                      final desk = Map<String, dynamic>.from(membership['desks'] as Map);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(child: Icon(_iconForType('${desk['type']}'))),
                                  const Spacer(),
                                  Chip(label: Text('${membership['role']}')),
                                ],
                              ),
                              const Spacer(),
                              Text('${desk['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              Text('${desk['type']} desk', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.key, size: 17),
                                  const SizedBox(width: 6),
                                  SelectableText('${desk['invite_code']}', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'family': return Icons.family_restroom;
      case 'business': return Icons.business_center_outlined;
      case 'roommates': return Icons.home_outlined;
      default: return Icons.groups_outlined;
    }
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _MessageCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
