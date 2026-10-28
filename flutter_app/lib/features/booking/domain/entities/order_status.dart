/// Where a booking is in its life. Pure rules, no display text and no API
/// strings (those belong to the UI and the data layer respectively).
enum OrderStatus { pending, inProgress, completed, cancelled }

extension OrderStatusRules on OrderStatus {
  /// Completed and cancelled are final.
  bool get isClosed => this == OrderStatus.completed || this == OrderStatus.cancelled;

  /// What this status may change into next:
  /// pending -> inProgress or cancelled; inProgress -> completed or cancelled.
  List<OrderStatus> get nextOptions => switch (this) {
    OrderStatus.pending => [OrderStatus.inProgress, OrderStatus.cancelled],
    OrderStatus.inProgress => [OrderStatus.completed, OrderStatus.cancelled],
    OrderStatus.completed || OrderStatus.cancelled => [],
  };

  /// Only a booking that has not started (or was cancelled) can be removed.
  bool get canBeDeleted => this == OrderStatus.pending || this == OrderStatus.cancelled;
}
