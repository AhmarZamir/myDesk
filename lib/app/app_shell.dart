import 'package:flutter/material.dart';
import '../core/ui_components.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../shared_desks/shared_desks_hub_screen.dart';
import '../workspace/documents_hub_screen.dart';
import '../workspace/collaboration_modules.dart';
import '../workspace/buddy_tasks_screen.dart';
import '../workspace/khata_hub_screen.dart';
import '../buddies/buddies_hub_screen.dart';
import 'account_dialog.dart';
import 'dashboard_screen.dart';
import 'entity_detail_screen.dart';

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
      case 1: return const DocumentsHubScreen();
      case 2: return const BillsScreen();
      case 3: return const BuddyTasksScreen();
      case 4: return const KhataHubScreen();
      case 5: return const BuddiesHubScreen();
      case 6: return const SharedDesksHubScreen();
      default: return DashboardScreen(onNavigate: _selectIndex, onOpenEntity: _openEntity);
    }
  }

  Future<void> _selectIndex(int value) async {
    setState(() => index = value);
    if (value == 3) await _notifications.markRead(kind: 'task');
    if (value == 4) await _notifications.markRead(kind: 'khata');
  }

  String _entityKind(Map<String, dynamic> item) {
    final kind = '${item['kind']}';
    final title = '${item['title']}'.toLowerCase();
    if (kind == 'general' && title.contains('bill')) return 'bill';
    return kind;
  }

  int _moduleForKind(String kind) {
    if (kind == 'document') return 1;
    if (kind == 'bill') return 2;
    if (kind == 'task') return 3;
    if (kind == 'khata') return 4;
    if (kind == 'buddy') return 5;
    if (kind == 'desk') return 6;
    return 0;
  }

  Future<void> _openEntity({required String kind, required String entityId, String? title, String? body, String? notificationId}) async {
    if (notificationId != null) await _notifications.markOneRead(notificationId);
    final module = _moduleForKind(kind);
    if (module > 0 && mounted) setState(() => index = module);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntityDetailScreen(
          kind: kind,
          entityId: entityId,
          fallbackTitle: title,
          fallbackBody: body,
        ),
      ),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final entityId = item['entity_id']?.toString();
    final kind = _entityKind(item);
    if (entityId == null || entityId.isEmpty || !const {'document', 'bill', 'task', 'khata'}.contains(kind)) {
      await _notifications.markOneRead('${item['id']}');
      await _selectIndex(_moduleForKind(kind));
      return;
    }
    await _openEntity(
      kind: kind,
      entityId: entityId,
      title: item['title']?.toString(),
      body: item['body']?.toString(),
      notificationId: '${item['id']}',
    );
  }

  Future<void> _openAccount() async {
    final updated = await showAccountDialog(context);
    if (mounted) setState(() => _profile = Future.value(updated));
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

  Widget _notificationButton(List<Map<String, dynamic>> rows) {
    final unreadCount = rows.where((n) => n['read_at'] == null).length;
    return PopupMenuButton<Object>(
      tooltip: 'Notifications',
      offset: const Offset(0, 50),
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 390),
      onSelected: (value) async {
        if (value == 'mark_all') {
          await _notifications.markRead();
          return;
        }
        if (value is Map<String, dynamic>) await _openNotification(value);
      },
      itemBuilder: (_) {
        final recent = rows.take(8).toList();
        return [
          PopupMenuItem<Object>(
            enabled: false,
            child: Row(children: [
              const Expanded(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800))),
              if (unreadCount > 0) Text('$unreadCount new', style: const TextStyle(color: Color(0xFF56A7FF), fontWeight: FontWeight.w700)),
            ]),
          ),
          if (recent.isEmpty)
            const PopupMenuItem<Object>(enabled: false, child: Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('You are all caught up.'))),
          ...recent.map((n) {
            final unread = n['read_at'] == null;
            return PopupMenuItem<Object>(
              value: n,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 17,
                  backgroundColor: unread ? const Color(0xFF1473E6) : null,
                  child: Icon(_notificationIcon('${n['kind']}'), size: 18, color: unread ? Colors.white : null),
                ),
                title: Text('${n['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                subtitle: (n['body'] ?? '').toString().trim().isEmpty ? null : Text('${n['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            );
          }),
          if (unreadCount > 0) const PopupMenuDivider(),
          if (unreadCount > 0) const PopupMenuItem<Object>(value: 'mark_all', child: Center(child: Text('Mark all as read'))),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _badgeIcon(Icons.notifications_none_rounded, unreadCount),
      ),
    );
  }

  IconData _notificationIcon(String kind) {
    switch (kind) {
      case 'task': return Icons.task_alt;
      case 'khata': return Icons.account_balance_wallet_outlined;
      case 'document': return Icons.description_outlined;
      case 'buddy': return Icons.person_add_alt_1;
      case 'desk': return Icons.groups_outlined;
      default: return Icons.notifications_none;
    }
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
      return CircleAvatar(key: ValueKey(url), radius: radius, backgroundImage: NetworkImage(url), backgroundColor: const Color(0xFF10192B));
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF1473E6), child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)));
  }

  Widget _brandIcon() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1473E6), Color(0xFF56A7FF)]), borderRadius: BorderRadius.circular(13)),
        child: const Icon(Icons.dashboard_customize, color: Colors.white),
      );

  Widget _brand() => Row(mainAxisSize: MainAxisSize.min, children: [
        _brandIcon(),
        const SizedBox(width: 10),
        const Text('myDesk', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.4)),
      ]);

  int _mobileTabForIndex() {
    if (index == 0) return 0;
    if (index == 1) return 1;
    if (index == 3) return 2;
    if (index == 6) return 3;
    return 4;
  }

  Future<void> _openMore() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('More tools', subtitle: 'Everything else stays one tap away without crowding navigation.'),
          const SizedBox(height: 14),
          _MoreDestination(icon: Icons.receipt_long_outlined, title: 'Bills', subtitle: 'Track shared and personal payments', onTap: () => Navigator.pop(context, 2)),
          _MoreDestination(icon: Icons.account_balance_wallet_outlined, title: 'Khata', subtitle: 'Manage balances with Buddies', onTap: () => Navigator.pop(context, 4)),
          _MoreDestination(icon: Icons.people_outline, title: 'Buddies', subtitle: 'People you collaborate with directly', onTap: () => Navigator.pop(context, 5)),
          _MoreDestination(icon: Icons.manage_accounts_outlined, title: 'Profile & account', subtitle: 'Profile photo, password and account settings', onTap: () {
            Navigator.pop(context);
            _openAccount();
          }),
        ]),
      ),
    );
    if (selected != null) await _selectIndex(selected);
  }

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
                Container(
                  width: constraints.maxWidth >= 1180 ? 250 : 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090C12),
                    border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                  ),
                  child: SafeArea(
                    child: Column(children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth >= 1180 ? 18 : 12, vertical: 18),
                        child: constraints.maxWidth >= 1180 ? _brand() : _brandIcon(),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: NavigationRail(
                          extended: constraints.maxWidth >= 1180,
                          selectedIndex: index,
                          onDestinationSelected: _selectIndex,
                          groupAlignment: -1,
                          backgroundColor: Colors.transparent,
                          destinations: List.generate(
                            _labels.length,
                            (i) => NavigationRailDestination(
                              icon: _badgeIcon(_icons[i], countFor(i)),
                              selectedIcon: _badgeIcon(_selectedIcon(_icons[i]), countFor(i)),
                              label: Text(_labels[i]),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: constraints.maxWidth >= 1180
                            ? FutureBuilder<Map<String, dynamic>?>(
                                future: _profile,
                                builder: (context, snap) {
                                  final name = snap.data?['full_name']?.toString() ?? 'Account';
                                  final avatar = snap.data?['avatar_url']?.toString();
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _openAccount,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(children: [
                                        _avatar(avatar, name, radius: 18),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                                        const Icon(Icons.more_horiz, size: 18),
                                      ]),
                                    ),
                                  );
                                },
                              )
                            : IconButton(tooltip: 'Profile & account', onPressed: _openAccount, icon: const Icon(Icons.account_circle_outlined)),
                      ),
                    ]),
                  ),
                ),
                Expanded(
                  child: Column(children: [
                    Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080B10).withValues(alpha: .94),
                        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_labels[index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text(_moduleHint(index), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ]),
                        ),
                        _notificationButton(rows),
                        const SizedBox(width: 6),
                        _profileButton(),
                      ]),
                    ),
                    Expanded(child: _pageForIndex()),
                  ]),
                ),
              ]),
            );
          }

          final mobileTab = _mobileTabForIndex();
          return Scaffold(
            appBar: AppBar(
              titleSpacing: 16,
              title: Row(children: [
                _brandIcon(),
                const SizedBox(width: 10),
                Expanded(child: Text(_labels[index], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              ]),
              actions: [_notificationButton(rows), _profileButton()],
            ),
            body: _pageForIndex(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: mobileTab,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) async {
                if (value == 0) await _selectIndex(0);
                if (value == 1) await _selectIndex(1);
                if (value == 2) await _selectIndex(3);
                if (value == 3) await _selectIndex(6);
                if (value == 4) await _openMore();
              },
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Docs'),
                NavigationDestination(icon: _badgeIcon(Icons.task_alt_outlined, taskCount), selectedIcon: _badgeIcon(Icons.task_alt, taskCount), label: 'Tasks'),
                const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Shared'),
                NavigationDestination(icon: _badgeIcon(Icons.grid_view_rounded, khataCount), selectedIcon: _badgeIcon(Icons.grid_view_rounded, khataCount), label: 'More'),
              ],
            ),
          );
        });
      },
    );
  }

  static String _moduleHint(int index) {
    switch (index) {
      case 1: return 'Private files, Buddy shares and Shared Desk content';
      case 2: return 'Bills, due dates and responsibility';
      case 3: return 'Personal, Buddy and Shared Desk tasks';
      case 4: return 'Balances and settlement history';
      case 5: return 'Trusted one-to-one collaboration';
      case 6: return 'Shared files, tasks, bills and people';
      default: return 'Your workspace at a glance';
    }
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

class _MoreDestination extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MoreDestination({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}
