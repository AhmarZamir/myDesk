import 'package:flutter/material.dart';

void main() {
  runApp(const MyDeskApp());
}

class MyDeskApp extends StatelessWidget {
  const MyDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'myDesk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3478F6)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final pages = const [
    DashboardScreen(),
    DocumentsScreen(),
    BillsScreen(),
    TasksScreen(),
    KhataScreen(),
    SharedDeskScreen(),
  ];

  final items = const [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Documents'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Bills'),
    NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Tasks'),
    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Khata'),
    NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Shared Desks'),
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
                  extended: constraints.maxWidth >= 1180,
                  selectedIndex: index,
                  onDestinationSelected: (value) => setState(() => index = value),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.dashboard_customize, color: Colors.white),
                        ),
                        if (constraints.maxWidth >= 1180) ...[
                          const SizedBox(width: 10),
                          const Text('myDesk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                    NavigationRailDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: Text('Documents')),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Bills')),
                    NavigationRailDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: Text('Tasks')),
                    NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Khata')),
                    NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Shared Desks')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[index]),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: items,
          ),
        );
      },
    );
  }
}

class ScreenFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const ScreenFrame({super.key, required this.title, required this.subtitle, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
                        ],
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Good morning, Ahmar',
      subtitle: 'Here is what needs your attention today.',
      action: const CircleAvatar(child: Icon(Icons.person)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 540 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.2,
                children: const [
                  StatCard(icon: Icons.folder, label: 'Documents', value: '24 files'),
                  StatCard(icon: Icons.receipt_long, label: 'Bills', value: '3 due'),
                  StatCard(icon: Icons.task_alt, label: 'Tasks', value: '5 pending'),
                  StatCard(icon: Icons.groups, label: 'Family Desk', value: '4 members'),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const SectionTitle('Needs attention'),
          const SizedBox(height: 12),
          const ActionCard(icon: Icons.electric_bolt, title: 'Electricity Bill', subtitle: 'Due Sep 15', trailing: 'Rs. 18,450'),
          const SizedBox(height: 10),
          const ActionCard(icon: Icons.assignment_ind, title: 'Family Certificate', subtitle: 'Shared with Family Desk', trailing: 'Shared'),
          const SizedBox(height: 10),
          const ActionCard(icon: Icons.payments_outlined, title: 'Brother owes you', subtitle: 'Laptop payment', trailing: 'Rs. 7,000'),
          const SizedBox(height: 28),
          const SectionTitle('Recent activity'),
          const SizedBox(height: 12),
          const ActivityTile(title: 'Ali completed “Pay internet bill”', time: '20 min ago'),
          const ActivityTile(title: 'Dad uploaded Property Tax Receipt', time: '2 hrs ago'),
          const ActivityTile(title: 'Family Certificate access updated', time: 'Yesterday'),
        ],
      ),
    );
  }
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const folders = [
      ('IDs', Icons.badge_outlined, '12 files'),
      ('Certificates', Icons.workspace_premium_outlined, '8 files'),
      ('Property', Icons.home_work_outlined, '6 files'),
      ('Medical', Icons.medical_information_outlined, '5 files'),
      ('Receipts', Icons.receipt_outlined, '18 files'),
      ('Other', Icons.folder_open_outlined, '4 files'),
    ];

    return ScreenFrame(
      title: 'Documents & Vault',
      subtitle: 'Keep important records organized, secure and shareable.',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.4,
              children: folders.map((folder) => FeatureCard(title: folder.$1, subtitle: folder.$3, icon: folder.$2)).toList(),
            );
          }),
          const SizedBox(height: 28),
          const SectionTitle('Recent documents'),
          const SizedBox(height: 12),
          const ActionCard(icon: Icons.picture_as_pdf_outlined, title: 'Family Registration Certificate', subtitle: 'Family Desk · Shared with 4 members', trailing: 'PDF'),
          const SizedBox(height: 10),
          const ActionCard(icon: Icons.picture_as_pdf_outlined, title: 'Passport', subtitle: 'Personal · Private', trailing: 'PDF'),
          const SizedBox(height: 10),
          const ActionCard(icon: Icons.image_outlined, title: 'Property Tax Receipt', subtitle: 'Family Desk · Added yesterday', trailing: 'IMG'),
        ],
      ),
    );
  }
}

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Bills & Payments',
      subtitle: 'Track household and personal bills without missing deadlines.',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add bill')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SummaryBanner(title: 'Total due', value: 'Rs. 32,870', note: '3 upcoming · 1 overdue'),
          SizedBox(height: 24),
          ActionCard(icon: Icons.electric_bolt, title: 'Electricity Bill', subtitle: 'Family Desk · Due Sep 15', trailing: 'Rs. 18,450'),
          SizedBox(height: 10),
          ActionCard(icon: Icons.wifi, title: 'Internet Bill', subtitle: 'Family Desk · Due Sep 18', trailing: 'Rs. 4,999'),
          SizedBox(height: 10),
          ActionCard(icon: Icons.local_fire_department_outlined, title: 'Gas Bill', subtitle: 'Family Desk · Due Sep 22', trailing: 'Rs. 9,421'),
        ],
      ),
    );
  }
}

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Tasks',
      subtitle: 'Assign responsibilities and keep everyone accountable.',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_task), label: const Text('Assign task')),
      child: Column(
        children: const [
          TaskTile(title: 'Pay electricity bill', owner: 'Ali', due: 'Sep 15', priority: 'High'),
          SizedBox(height: 10),
          TaskTile(title: 'Renew car insurance', owner: 'Ahmar', due: 'Sep 20', priority: 'Medium'),
          SizedBox(height: 10),
          TaskTile(title: 'Upload property receipt', owner: 'Dad', due: 'Sep 24', priority: 'Low'),
          SizedBox(height: 10),
          TaskTile(title: 'Buy monthly groceries', owner: 'Mom', due: 'Sep 26', priority: 'Medium'),
        ],
      ),
    );
  }
}

class KhataScreen extends StatelessWidget {
  const KhataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Khata',
      subtitle: 'Simple shared money tracking between people you trust.',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add entry')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SummaryBanner(title: 'You are owed', value: 'Rs. 12,600', note: 'You owe Rs. 1,200'),
          SizedBox(height: 24),
          ActionCard(icon: Icons.arrow_downward, title: 'Ali owes you', subtitle: 'Laptop payment · Aug 28', trailing: 'Rs. 7,000'),
          SizedBox(height: 10),
          ActionCard(icon: Icons.arrow_downward, title: 'Riya owes you', subtitle: 'Cab fare · Sep 3', trailing: 'Rs. 5,600'),
          SizedBox(height: 10),
          ActionCard(icon: Icons.arrow_upward, title: 'You owe Mom', subtitle: 'Groceries · Sep 5', trailing: 'Rs. 1,200'),
        ],
      ),
    );
  }
}

class SharedDeskScreen extends StatelessWidget {
  const SharedDeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Shared Desks',
      subtitle: 'Create private spaces for family, business, roommates or other trusted groups.',
      action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.group_add_outlined), label: const Text('Create desk')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 780 ? 3 : constraints.maxWidth >= 500 ? 2 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.45,
              children: const [
                DeskCard(name: 'Family', members: '4 members', documents: '18 documents', tasks: '6 tasks'),
                DeskCard(name: 'Business', members: '2 members', documents: '7 documents', tasks: '3 tasks'),
                DeskCard(name: 'Home', members: '3 members', documents: '10 documents', tasks: '4 tasks'),
              ],
            );
          }),
          const SizedBox(height: 28),
          const SectionTitle('Family Desk activity'),
          const SizedBox(height: 12),
          const ActivityTile(title: 'Family Registration Certificate shared with everyone', time: 'Today'),
          const ActivityTile(title: 'Ali was assigned “Pay electricity bill”', time: 'Yesterday'),
          const ActivityTile(title: 'Dad added a property document', time: '2 days ago'),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const StatCard({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Text(value, style: const TextStyle(color: Colors.black54))])),
          ],
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const FeatureCard({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 14), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(subtitle, style: const TextStyle(color: Colors.black54))])), const Icon(Icons.chevron_right)]),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  const ActionCard({super.key, required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: Text(trailing, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final String title;
  final String owner;
  final String due;
  final String priority;
  const TaskTile({super.key, required this.title, required this.owner, required this.due, required this.priority});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const Icon(Icons.radio_button_unchecked),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Assigned to $owner · Due $due'),
        trailing: Chip(label: Text(priority)),
      ),
    );
  }
}

class DeskCard extends StatelessWidget {
  final String name;
  final String members;
  final String documents;
  final String tasks;
  const DeskCard({super.key, required this.name, required this.members, required this.documents, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(child: Text(name.substring(0, 1))), const Spacer(), const Icon(Icons.more_horiz)]),
          const Spacer(),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(members),
          Text(documents),
          Text(tasks),
        ]),
      ),
    );
  }
}

class SummaryBanner extends StatelessWidget {
  final String title;
  final String value;
  final String note;
  const SummaryBanner({super.key, required this.title, required this.value, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), Text(note)]),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final String title;
  final String time;
  const ActivityTile({super.key, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.history)),
      title: Text(title),
      subtitle: Text(time),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800));
}
