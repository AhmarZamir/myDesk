import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../shared_desks/shared_desks_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final _pages = const [
    _DashboardPage(),
    _ModulePage(title: 'Documents & Vault', subtitle: 'Store, organize and securely share important documents.', icon: Icons.folder_outlined),
    _ModulePage(title: 'Bills & Payments', subtitle: 'Track bills, due dates and payment status across your desks.', icon: Icons.receipt_long_outlined),
    _ModulePage(title: 'Tasks', subtitle: 'Assign responsibilities and track what needs to get done.', icon: Icons.task_alt_outlined),
    _ModulePage(title: 'Khata', subtitle: 'Track shared balances and who owes whom.', icon: Icons.account_balance_wallet_outlined),
    SharedDesksScreen(),
  ];

  static const _labels = ['Home', 'Documents', 'Bills', 'Tasks', 'Khata', 'Shared Desks'];
  static const _icons = [
    Icons.home_outlined,
    Icons.folder_outlined,
    Icons.receipt_long_outlined,
    Icons.task_alt_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.groups_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1160,
                  selectedIndex: index,
                  onDestinationSelected: (value) => setState(() => index = value),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.dashboard_customize, color: Colors.white),
                        ),
                        if (constraints.maxWidth >= 1160) ...[
                          const SizedBox(width: 10),
                          const Text('myDesk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(tooltip: 'Sign out', onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout)),
                      ),
                    ),
                  ),
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationRailDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcon(_icons[i])), label: Text(_labels[i])),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pages[index]),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('myDesk', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [IconButton(tooltip: 'Sign out', onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout))],
          ),
          body: _pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: List.generate(
              _labels.length,
              (i) => NavigationDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcon(_icons[i])), label: _labels[i]),
            ),
          ),
        );
      },
    );
  }

  static IconData _selectedIcon(IconData icon) {
    if (icon == Icons.home_outlined) return Icons.home;
    if (icon == Icons.folder_outlined) return Icons.folder;
    if (icon == Icons.receipt_long_outlined) return Icons.receipt_long;
    if (icon == Icons.task_alt_outlined) return Icons.task_alt;
    if (icon == Icons.account_balance_wallet_outlined) return Icons.account_balance_wallet;
    return Icons.groups;
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Your Desk', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Everything important, organized in one place.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.1,
              children: const [
                _StatCard(icon: Icons.folder_outlined, title: 'Documents', value: 'Your secure vault'),
                _StatCard(icon: Icons.receipt_long_outlined, title: 'Bills', value: 'Track what is due'),
                _StatCard(icon: Icons.task_alt_outlined, title: 'Tasks', value: 'Shared responsibilities'),
                _StatCard(icon: Icons.groups_outlined, title: 'Shared Desks', value: 'Family & trusted groups'),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        const Text('What myDesk manages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                ListTile(leading: Icon(Icons.security_outlined), title: Text('Personal records'), subtitle: Text('Private documents, receipts, certificates and reminders')),
                Divider(),
                ListTile(leading: Icon(Icons.family_restroom), title: Text('Shared life'), subtitle: Text('Family files, common bills, tasks and expenses')),
                Divider(),
                ListTile(leading: Icon(Icons.sync), title: Text('Same product everywhere'), subtitle: Text('The same account and workflows on web and mobile')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _StatCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: const TextStyle(color: Colors.black54))])),
          ],
        ),
      ),
    );
  }
}

class _ModulePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _ModulePage({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              children: [
                Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                const Text('Connected module foundation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                const Text('This module is part of the same authenticated myDesk workspace. Persistence and create/edit flows are the next implementation layer.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
