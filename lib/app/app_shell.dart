import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../shared_desks/shared_desks_screen.dart';
import '../workspace/documents_screen.dart';
import '../workspace/collaboration_modules.dart';
import '../workspace/khata_screen.dart';
import '../buddies/buddies_screen.dart';
import 'account_dialog.dart';
import 'dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const _labels = ['Home', 'Documents', 'Bills', 'Tasks', 'Khata', 'Buddies', 'Shared Desks'];
  static const _icons = [
    Icons.home_outlined,
    Icons.folder_outlined,
    Icons.receipt_long_outlined,
    Icons.task_alt_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.people_outline,
    Icons.groups_outlined,
  ];

  Widget _pageForIndex() {
    switch (index) {
      case 1: return const DocumentsScreen();
      case 2: return const BillsScreen();
      case 3: return const TasksScreen();
      case 4: return const BuddyKhataScreen();
      case 5: return const BuddiesScreen();
      case 6: return const SharedDesksScreen();
      default: return DashboardScreen(onNavigate: (value) => setState(() => index = value));
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You will need to sign in again to access your private workspace.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
            ],
          ),
        ) ?? false;
    if (confirmed) await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      if (wide) {
        return Scaffold(
          body: Row(children: [
            NavigationRail(
              extended: constraints.maxWidth >= 1160,
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                ]),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Account', onPressed: () => showAccountDialog(context), icon: const Icon(Icons.account_circle_outlined)),
                      IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout)),
                    ]),
                  ),
                ),
              ),
              destinations: List.generate(
                _labels.length,
                (i) => NavigationRailDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcon(_icons[i])), label: Text(_labels[i])),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pageForIndex()),
          ]),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('myDesk', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(tooltip: 'Account', onPressed: () => showAccountDialog(context), icon: const Icon(Icons.account_circle_outlined)),
            IconButton(tooltip: 'Sign out', onPressed: _signOut, icon: const Icon(Icons.logout)),
          ],
        ),
        body: _pageForIndex(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: List.generate(
            _labels.length,
            (i) => NavigationDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcon(_icons[i])), label: _labels[i]),
          ),
        ),
      );
    });
  }

  static IconData _selectedIcon(IconData icon) {
    if (icon == Icons.home_outlined) return Icons.home;
    if (icon == Icons.folder_outlined) return Icons.folder;
    if (icon == Icons.receipt_long_outlined) return Icons.receipt_long;
    if (icon == Icons.task_alt_outlined) return Icons.task_alt;
    if (icon == Icons.account_balance_wallet_outlined) return Icons.account_balance_wallet;
    if (icon == Icons.people_outline) return Icons.people;
    return Icons.groups;
  }
}
