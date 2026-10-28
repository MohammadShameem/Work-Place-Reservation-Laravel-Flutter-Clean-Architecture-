import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/booking_providers.dart';

sealed class OrderDetailEvent {
  const OrderDetailEvent();
}

/// Tell the user something (a status change was refused, say).
final class OrderMessage extends OrderDetailEvent {
  const OrderMessage(this.text);

  final String text;
}

/// The order is gone; close the screen.
final class OrderDeleted extends OrderDetailEvent {
  const OrderDeleted();
}

class OrderDetailState {
  const OrderDetailState({
    this.order,
    this.isLoading = true,
    this.error,
    this.isMutating = false,
    this.event,
  });

  final Order? order;
  final bool isLoading;
  final String? error;

  /// A status change or delete is in flight; the buttons are disabled.
  final bool isMutating;
  final OrderDetailEvent? event;

  static const _keep = Object();

  OrderDetailState copyWith({
    Object? order = _keep,
    bool? isLoading,
    Object? error = _keep,
    bool? isMutating,
    Object? event = _keep,
  }) {
    return OrderDetailState(
      order: identical(order, _keep) ? this.order : order as Order?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _keep) ? this.error : error as String?,
      isMutating: isMutating ?? this.isMutating,
      event: identical(event, _keep) ? this.event : event as OrderDetailEvent?,
    );
  }
}

class OrderDetailViewModel extends Notifier<OrderDetailState> {
  OrderDetailViewModel(this.orderId);

  final int orderId;

  @override
  OrderDetailState build() {
    Future.microtask(load);
    return const OrderDetailState();
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final order = await ref.read(bookingRepositoryProvider).order(orderId);
      if (ref.mounted) state = state.copyWith(order: order, isLoading: false);
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  Future<void> changeStatus(OrderStatus next) async {
    state = state.copyWith(isMutating: true);

    try {
      final updated = await ref.read(bookingRepositoryProvider).updateStatus(orderId, next);
      if (ref.mounted) state = state.copyWith(order: updated, isMutating: false);
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isMutating: false, event: OrderMessage(failure.message));
    }
  }

  Future<void> delete() async {
    state = state.copyWith(isMutating: true);

    try {
      await ref.read(bookingRepositoryProvider).deleteOrder(orderId);
      if (ref.mounted) state = state.copyWith(isMutating: false, event: const OrderDeleted());
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isMutating: false, event: OrderMessage(failure.message));
    }
  }

  void consumeEvent() {
    if (ref.mounted) state = state.copyWith(event: null);
  }
}

final orderDetailViewModelProvider = NotifierProvider.autoDispose
    .family<OrderDetailViewModel, OrderDetailState, int>(OrderDetailViewModel.new);
