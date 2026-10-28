import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/order.dart';
import '../providers/booking_providers.dart';

class WorkstationOrdersState {
  const WorkstationOrdersState({this.orders = const [], this.isLoading = true, this.error});

  final List<Order> orders;
  final bool isLoading;
  final String? error;
}

/// The orders booked at one workstation (first page only).
class WorkstationOrdersViewModel extends Notifier<WorkstationOrdersState> {
  WorkstationOrdersViewModel(this.workstationId);

  final int workstationId;

  @override
  WorkstationOrdersState build() {
    Future.microtask(load);
    return const WorkstationOrdersState();
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = WorkstationOrdersState(orders: state.orders);

    try {
      final orders = await ref.read(bookingRepositoryProvider).ordersForWorkstation(workstationId);
      if (ref.mounted) state = WorkstationOrdersState(orders: orders, isLoading: false);
    } on Failure catch (failure) {
      if (ref.mounted) state = WorkstationOrdersState(orders: state.orders, isLoading: false, error: failure.message);
    }
  }
}

final workstationOrdersViewModelProvider = NotifierProvider.autoDispose
    .family<WorkstationOrdersViewModel, WorkstationOrdersState, int>(WorkstationOrdersViewModel.new);
