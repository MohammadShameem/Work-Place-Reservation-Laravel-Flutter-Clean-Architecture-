import '../../../workstations/domain/entities/workstation.dart';
import 'order_status.dart';
import 'workstation_slot.dart';

/// An order IS a workstation-slot booking — no line items, no total.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    this.notes,
    this.workstation,
    this.workstationSlot,
    required this.createdAt,
  });

  final int id;
  final String orderNumber;
  final String customerName;
  final OrderStatus status;
  final String? notes;
  final Workstation? workstation;
  final WorkstationSlot? workstationSlot;
  final DateTime createdAt;
}
