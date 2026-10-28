import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../workstations/domain/entities/workstation.dart';
import '../viewmodel/workstation_orders_view_model.dart';
import '../widgets/status_chip.dart';
import 'order_detail_page.dart';

class WorkstationOrdersPage extends ConsumerWidget {
  const WorkstationOrdersPage({super.key, required this.workstation});

  final Workstation workstation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = workstationOrdersViewModelProvider(workstation.id);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    Widget body;
    if (state.isLoading && state.orders.isEmpty) {
      body = const LoadingView();
    } else if (state.error != null && state.orders.isEmpty) {
      body = ErrorView(message: state.error!, onRetry: viewModel.load);
    } else if (state.orders.isEmpty) {
      body = const Center(child: Text('No orders at this workstation yet.'));
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.orders.length,
          itemBuilder: (context, index) {
            final order = state.orders[index];
            final slot = order.workstationSlot;
            final time = slot == null ? '' : ' · ${DateFormat('d MMM, h:mm a').format(slot.startsAt)}';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(order.orderNumber),
                subtitle: Text('${order.customerName}$time'),
                trailing: StatusChip(status: order.status),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
                  );
                  if (context.mounted) await viewModel.load();
                },
              ),
            );
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: Text(workstation.name)), body: body);
  }
}
