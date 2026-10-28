import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/booking_providers.dart';

class OrdersState {
  const OrdersState({
    this.isLoading = true,
    this.error,
    this.orders = const [],
    this.statusFilter,
    this.workstationFilter,
  });

  final bool isLoading;
  final String? error;
  final List<Order> orders;
  final OrderStatus? statusFilter;
  final int? workstationFilter;

  static const _keep = Object();

  OrdersState copyWith({
    bool? isLoading,
    Object? error = _keep,
    List<Order>? orders,
    Object? statusFilter = _keep,
    Object? workstationFilter = _keep,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _keep) ? this.error : error as String?,
      orders: orders ?? this.orders,
      statusFilter: identical(statusFilter, _keep) ? this.statusFilter : statusFilter as OrderStatus?,
      workstationFilter: identical(workstationFilter, _keep) ? this.workstationFilter : workstationFilter as int?,
    );
  }
}

/// The "my bookings" list with its two filters. Dropped when the tab closes,
/// which also means one user's orders never linger after logging out.
class OrdersViewModel extends Notifier<OrdersState> {
  @override
  OrdersState build() {
    Future.microtask(load);
    return const OrdersState();
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final orders = await ref.read(bookingRepositoryProvider).orders(
        status: state.statusFilter,
        workstationId: state.workstationFilter,
      );
      if (ref.mounted) state = state.copyWith(isLoading: false, orders: orders);
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  void setStatusFilter(OrderStatus? status) {
    state = state.copyWith(statusFilter: status);
    load();
  }

  void setWorkstationFilter(int? workstationId) {
    state = state.copyWith(workstationFilter: workstationId);
    load();
  }
}

final ordersViewModelProvider = NotifierProvider.autoDispose<OrdersViewModel, OrdersState>(OrdersViewModel.new);
