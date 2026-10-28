import '../../../workstations/data/models/workstation_mapper.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/slot_hold.dart';
import '../../domain/entities/workstation_slot.dart';

/// JSON <-> entity translation for booking. The only place that knows the
/// API's field names and the strings it uses for statuses.

abstract final class OrderStatusApi {
  static String toApi(OrderStatus status) => switch (status) {
    OrderStatus.pending => 'pending',
    OrderStatus.inProgress => 'in_progress',
    OrderStatus.completed => 'completed',
    OrderStatus.cancelled => 'cancelled',
  };

  static OrderStatus fromApi(String value) {
    return OrderStatus.values.firstWhere(
      (status) => toApi(status) == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

abstract final class SlotMapper {
  static WorkstationSlot fromJson(Map<String, dynamic> json) => WorkstationSlot(
    id: json['id'] as int,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    status: _status(json['status'] as String),
    heldUntil: json['held_until'] == null ? null : DateTime.parse(json['held_until'] as String),
  );

  static SlotStatus _status(String value) => switch (value) {
    'available' => SlotStatus.available,
    'held' => SlotStatus.held,
    'held_by_you' => SlotStatus.heldByYou,
    // Anything unknown is treated as taken, so a newer server can never
    // trick an older app into offering a slot that isn't free.
    _ => SlotStatus.booked,
  };
}

abstract final class SlotHoldMapper {
  /// [deviceNow] is only used to measure how far this device's clock is from
  /// the server's at the moment the hold was issued.
  static SlotHold fromJson(Map<String, dynamic> json, {required DateTime deviceNow}) {
    final serverTime = DateTime.parse(json['server_time'] as String);

    return SlotHold(
      slotId: json['workstation_slot_id'] as int,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      serverClockOffset: serverTime.difference(deviceNow.toUtc()),
    );
  }
}

abstract final class OrderMapper {
  static Order fromJson(Map<String, dynamic> json) {
    final workstation = json['workstation'];
    final slot = json['workstation_slot'];

    return Order(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      customerName: json['customer_name'] as String,
      status: OrderStatusApi.fromApi(json['status'] as String),
      notes: json['notes'] as String?,
      workstation: workstation is Map<String, dynamic> ? WorkstationMapper.fromJson(workstation) : null,
      workstationSlot: slot is Map<String, dynamic> ? SlotMapper.fromJson(slot) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
