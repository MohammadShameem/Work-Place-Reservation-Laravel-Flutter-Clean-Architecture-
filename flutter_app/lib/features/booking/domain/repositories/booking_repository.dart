import '../entities/order.dart';
import '../entities/order_status.dart';
import '../entities/slot_hold.dart';
import '../entities/workstation_slot.dart';

/// Booking, as the app sees it: look at slots, hold one, turn it into an
/// order, manage orders. Nothing here mentions HTTP, JSON or headers.
/// Every method fails with a `Failure` (see core/error/failure.dart).
abstract interface class BookingRepository {
  /// One day's time slots at a workstation, each as seen by the current user.
  Future<List<WorkstationSlot>> slots(int workstationId, DateTime day);

  /// Reserve a slot while the user fills in the confirm screen. Fails with
  /// `SlotHeldFailure` / `SlotBookedFailure` if someone beat them to it.
  /// Calling it again while still holding the slot renews the hold.
  Future<SlotHold> holdSlot(int slotId);

  /// Give the slot back. Always safe to call; skipping it only means the
  /// hold lapses on its own after a few minutes.
  Future<void> releaseSlot(int slotId);

  /// Book the slot. Each call is one attempt to book — it can't create a
  /// second order for the same attempt if the first answer is lost.
  Future<Order> bookSlot({required int slotId, required String customerName, String? notes});

  Future<List<Order>> orders({OrderStatus? status, int? workstationId});

  Future<List<Order>> ordersForWorkstation(int workstationId);

  Future<Order> order(int id);

  Future<Order> updateStatus(int id, OrderStatus status);

  Future<void> deleteOrder(int id);
}
