import '../../domain/entities/order_status.dart';

/// How a status is worded on screen. Display text is the UI's business, so
/// it lives here and not on the domain enum.
extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.inProgress => 'In Progress',
    OrderStatus.completed => 'Completed',
    OrderStatus.cancelled => 'Cancelled',
  };
}
