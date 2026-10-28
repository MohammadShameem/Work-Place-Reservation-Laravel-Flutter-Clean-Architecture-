import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../viewmodel/order_detail_view_model.dart';
import '../widgets/order_status_label.dart';
import '../widgets/status_chip.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final int orderId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Order order) async {
    final viewModel = ref.read(orderDetailViewModelProvider(orderId).notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete order?'),
        content: Text('This cancels the booking for ${order.orderNumber}. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) viewModel.delete();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = orderDetailViewModelProvider(orderId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    ref.listen(provider.select((s) => s.event), (previous, event) {
      if (event == null) return;
      viewModel.consumeEvent();

      switch (event) {
        case OrderMessage(:final text):
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
        case OrderDeleted():
          Navigator.of(context).pop();
      }
    });

    final order = state.order;

    return Scaffold(
      appBar: AppBar(title: Text(order?.orderNumber ?? 'Order')),
      body: state.isLoading && order == null
          ? const LoadingView()
          : state.error != null && order == null
          ? ErrorView(message: state.error!, onRetry: viewModel.load)
          : order == null
          ? const SizedBox.shrink()
          : _OrderBody(
              order: order,
              isMutating: state.isMutating,
              onChangeStatus: viewModel.changeStatus,
              onDelete: () => _confirmDelete(context, ref, order),
            ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    required this.isMutating,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final Order order;
  final bool isMutating;
  final void Function(OrderStatus) onChangeStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slot = order.workstationSlot;
    final dateFormat = DateFormat('EEEE, d MMMM');
    final timeFormat = DateFormat('h:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(order.customerName, style: textTheme.headlineSmall),
            StatusChip(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Text(order.orderNumber, style: textTheme.bodySmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.workstation != null) ...[
                  _InfoRow(icon: Icons.factory_outlined, label: order.workstation!.name),
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.place_outlined, label: order.workstation!.location),
                ],
                if (slot != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.event_outlined, label: dateFormat.format(slot.startsAt)),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: '${timeFormat.format(slot.startsAt)} - ${timeFormat.format(slot.endsAt)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.notes, label: order.notes!),
        ],
        const SizedBox(height: 24),
        if (order.status.nextOptions.isNotEmpty) ...[
          Text('Change status', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final next in order.status.nextOptions)
                OutlinedButton(
                  onPressed: isMutating ? null : () => onChangeStatus(next),
                  child: Text('Mark as ${next.label}'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (order.status.canBeDeleted)
          OutlinedButton.icon(
            onPressed: isMutating ? null : onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete order', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
