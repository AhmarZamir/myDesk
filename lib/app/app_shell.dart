import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
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
  int index = Uri.base.queryParameters['buddy']?.isNotEmpty == true ? 5 : 0;
  final _notifications = NotificationService();
  final _auth = AuthService();
  late Future<Map<String, dynamic>?> _profile;

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

  @override
  void initState() {
    super.initState();
    _profile = _auth.fetchProfile();
  }

  Widget _pageForIndex() {
    switch (index) {
      case 1: return const DocumentsScreen();
      case 2: return const BillsScreen();
      case 3: return const TasksScreen();
      case 4: return const BuddyKhataScreen();
      case 5: return const BuddiesScreen();
      case 6: return const SharedDesksScreen();
      default: return DashboardScreen(onNavigate: _selectIndex);
    }
  }

  Future<void> _selectIndex(int value) async {
    setState(() => index = value);
    if (value == 3) await _notifications.markRead(kind: 'task');
    if (value == 4) await _notifications.markRead(kind: 'khata');
  }

  Future<void> _openAccount() async {
    final updated = await showAccountDialog(context);
    if (mounted) {
      setState(() {
        _profile = Future.value(updated);
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You will need to sign in again to access your workspace.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
            ],
          ),
        ) ?? false;
    if (confirmed) await _auth.signOut();
  }

  Widget _badgeIcon(IconData icon, int count) {
    final child = Icon(icon);
    if (count <= 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: const Color(0xFF2F80FF),
      textColor: Colors.white,
      child: child,
    );
  }

  Widget _profileButton() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['full_name']?.toString() ?? 'Account';
        final avatar = profile?['avatar_url']?.toString();
        return PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 50),
          onSelected: (value) async {
            if (value == 'profile') await _openAccount();
            if (value == 'logout') await _signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Row(children: [
                _avatar(avatar, name, radius: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'profile', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.manage_accounts_outlined), title: Text('Profile & account'))),
            const PopupMenuItem(value: 'logout', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout), title: Text('Sign out'))),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF2F80FF).withValues(alpha: .55)),
            ),
            child: _avatar(avatar, name, radius: 18),
          ),
        );
      },
    );
  }

  Widget _avatar(String? url, String name, {double radius = 18}) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        key: ValueKey(url),
        radius: radius,
        backgroundImage: NetworkImage(url),
        backgroundColor: const Color(0xFF10192B),
      );
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1473E6),
      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  Widget _brandIcon() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1473E6), Color(0xFF56A7FF)]),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.dashboard_customize, color: Colors.white),
      );

  Widget _brand() => Row(mainAxisSize: MainAxisSize.min, children: [
        _brandIcon(),
        const SizedBox(width: 10),
        const Text('myDesk', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.4)),
      ]);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notifications.stream(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        final unread = rows.where((n) => n['read_at'] == null).toList();
        final taskCount = unread.where((n) => n['kind'] == 'task').length;
        final khataCount = unread.where((n) => n['kind'] == 'khata').length;
        int countFor(int i) => i == 3 ? taskCount : i == 4 ? khataCount : 0;

        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Scaffold(
              body: Row(children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1160,
                  selectedIndex: index,
                  onDestinationSelected: _selectIndex,
                  destinations: List.generate(
                    _labels.length,
                    (i) => NavigationRailDestination(
                      icon: _badgeIcon(_icons[i], countFor(i)),
                      selectedIcon: _badgeIcon(_selectedIcon(_icons[i]), countFor(i)),
                      label: Text(_labels[i]),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(children: [
                    Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
                      child: Row(children: [
                        Expanded(child: Text(_labels[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                        _profileButton(),
                      ]),
                    ),
                    Expanded(child: _pageForIndex()),
                  ]),
                ),
              ]),
            );
          }

          return Scaffold(
            appBar: AppBar(
              titleSpacing: 18,
              title: _brand(),
              actions: [_profileButton()],
            ),
            body: _pageForIndex(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: _selectIndex,
              destinations: List.generate(
                _labels.length,
                (i) => NavigationDestination(
                  icon: _badgeIcon(_icons[i], countFor(i)),
                  selectedIcon: _badgeIcon(_selectedIcon(_icons[i]), countFor(i)),
                  label: _labels[i],
                ),
              ),
            ),
          );
        });
      },
    );
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
