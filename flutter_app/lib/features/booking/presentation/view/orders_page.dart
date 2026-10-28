import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../workstations/presentation/viewmodel/workstations_view_model.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../viewmodel/orders_view_model.dart';
import '../widgets/order_status_label.dart';
import '../widgets/status_chip.dart';
import 'order_detail_page.dart';

/// Existing bookings. Booking starts from the Workstations tab (pick a
/// workstation, then a time slot) — this tab is for viewing and managing them.
class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersViewModelProvider);
    final viewModel = ref.read(ordersViewModelProvider.notifier);
    final workstations = ref.watch(workstationsViewModelProvider).items;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownMenu<OrderStatus?>(
                  label: const Text('Status'),
                  initialSelection: state.statusFilter,
                  onSelected: viewModel.setStatusFilter,
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: null, label: 'All'),
                    for (final status in OrderStatus.values) DropdownMenuEntry(value: status, label: status.label),
                  ],
                ),
                DropdownMenu<int?>(
                  label: const Text('Workstation'),
                  initialSelection: state.workstationFilter,
                  onSelected: viewModel.setWorkstationFilter,
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: null, label: 'All'),
                    for (final ws in workstations) DropdownMenuEntry(value: ws.id, label: ws.name),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _OrderList(state: state, onRefresh: viewModel.load)),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.state, required this.onRefresh});

  final OrdersState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingView();
    }
    if (state.error != null && state.orders.isEmpty) {
      return ErrorView(message: state.error!, onRetry: onRefresh);
    }
    if (state.orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No bookings match this filter.\nGo to the Workstations tab to book a time slot.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: state.orders.length,
        itemBuilder: (context, index) => _OrderTile(order: state.orders[index], onChanged: onRefresh),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onChanged});

  final Order order;

  /// The detail screen may have changed or deleted the order.
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final slot = order.workstationSlot;
    final time = slot == null ? '' : ' · ${DateFormat('d MMM, h:mm a').format(slot.startsAt)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(order.orderNumber),
        subtitle: Text(
          '${order.customerName}'
          '${order.workstation != null ? ' · ${order.workstation!.name}' : ''}'
          '$time',
        ),
        trailing: StatusChip(status: order.status),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
          );
          if (context.mounted) await onChanged();
        },
      ),
    );
  }
}
