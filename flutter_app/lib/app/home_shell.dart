import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../features/booking/presentation/view/orders_page.dart';
import '../features/booking/presentation/view/slot_picker_page.dart';
import '../features/booking/presentation/view/workstation_orders_page.dart';
import '../features/workstations/domain/entities/workstation.dart';
import '../features/workstations/presentation/view/workstations_page.dart';

/// The logged-in app shell, and the one place that knows how the features
/// connect: the workstations feature is told where "Order" leads rather than
/// importing the booking screens itself.
///
/// Uses a side NavigationRail on wide windows (web, desktop, tablet
/// landscape) and a BottomNavigationBar on narrow ones (phones).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.factory_outlined, selectedIcon: Icons.factory, label: 'Workstations'),
    (icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Orders'),
  ];

  Future<bool?> _openBooking(BuildContext context, Workstation workstation) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SlotPickerPage(workstation: workstation)),
    );
  }

  void _openWorkstationOrders(BuildContext context, Workstation workstation) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkstationOrdersPage(workstation: workstation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final user = ref.watch(authViewModelProvider).user;

    final pages = [
      WorkstationsPage(onOrder: _openBooking, onShowOrders: _openWorkstationOrders),
      const OrdersPage(),
    ];
    final body = pages[_index];

    if (!isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_destinations[_index].label),
          actions: [_AccountMenu(userName: user?.name)],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workstation Orders'),
        actions: [_AccountMenu(userName: user?.name)],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) {
        if (value == 'logout') ref.read(authViewModelProvider.notifier).logout();
      },
      itemBuilder: (context) => [
        if (userName != null)
          PopupMenuItem(enabled: false, child: Text(userName!, style: const TextStyle(fontWeight: FontWeight.bold))),
        const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Log out'))),
      ],
    );
  }
}
