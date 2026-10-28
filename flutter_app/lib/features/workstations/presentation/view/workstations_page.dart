import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../domain/entities/workstation.dart';
import '../viewmodel/workstations_view_model.dart';

/// Lists the workstations. Where "Order" and "see its orders" lead is not
/// this feature's business — the app shell decides and passes it in, so the
/// workstations feature never has to know the booking screens exist.
class WorkstationsPage extends ConsumerWidget {
  const WorkstationsPage({super.key, required this.onOrder, required this.onShowOrders});

  /// Opens the booking flow for a workstation; completes with true if a booking was made.
  final Future<bool?> Function(BuildContext context, Workstation workstation) onOrder;

  final void Function(BuildContext context, Workstation workstation) onShowOrders;

  Future<void> _addWorkstation(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New workstation'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code (e.g. WS-05)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location (e.g. Building A - Floor 1)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final problem = await ref.read(workstationsViewModelProvider.notifier).create(
                name: nameController.text.trim(),
                code: codeController.text.trim(),
                location: locationController.text.trim(),
              );

              if (!dialogContext.mounted) return;
              if (problem == null) {
                Navigator.pop(dialogContext, true);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(problem)));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    nameController.dispose();
    codeController.dispose();
    locationController.dispose();

    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workstation created.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workstationsViewModelProvider);
    final viewModel = ref.read(workstationsViewModelProvider.notifier);

    ref.listen(workstationsViewModelProvider.select((s) => s.notice), (previous, notice) {
      if (notice == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      viewModel.consumeNotice();
    });

    Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = const LoadingView();
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(message: state.error!, onRetry: viewModel.load);
    } else if (state.items.isEmpty) {
      body = const Center(child: Text('No workstations yet. Tap + to add one.'));
    } else {
      body = RefreshIndicator(
        onRefresh: viewModel.load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.items.length,
          itemBuilder: (context, index) => _WorkstationCard(
            workstation: state.items[index],
            onOrder: onOrder,
            onShowOrders: onShowOrders,
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addWorkstation(context, ref),
        tooltip: 'Add workstation',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WorkstationCard extends ConsumerWidget {
  const _WorkstationCard({required this.workstation, required this.onOrder, required this.onShowOrders});

  final Workstation workstation;
  final Future<bool?> Function(BuildContext context, Workstation workstation) onOrder;
  final void Function(BuildContext context, Workstation workstation) onShowOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final viewModel = ref.read(workstationsViewModelProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: workstation.isActive ? colors.primaryContainer : colors.surfaceContainerHighest,
              child: Text(workstation.code.replaceAll('WS-', '')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onShowOrders(context, workstation),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workstation.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${workstation.code} · ${workstation.location}'
                      '${workstation.isActive ? '' : ' · inactive'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (workstation.ordersCount != null)
                      Text('${workstation.ordersCount} order(s)', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: workstation.isActive,
                  onChanged: (value) => viewModel.setActive(workstation, value),
                ),
                FilledButton.tonal(
                  onPressed: workstation.isBookable
                      ? () async {
                          final booked = await onOrder(context, workstation);
                          // A new booking changes this workstation's order count.
                          if (booked == true) viewModel.load();
                        }
                      : null,
                  child: const Text('Order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
