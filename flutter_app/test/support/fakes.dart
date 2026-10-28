import 'dart:async';
import 'dart:math';

import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/auth/domain/entities/app_user.dart';
import 'package:order_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:order_app/features/booking/domain/entities/order.dart';
import 'package:order_app/features/booking/domain/entities/order_status.dart';
import 'package:order_app/features/booking/domain/entities/slot_hold.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';
import 'package:order_app/features/booking/domain/repositories/booking_repository.dart';
import 'package:order_app/features/workstations/domain/entities/workstation.dart';
import 'package:order_app/features/workstations/domain/repositories/workstation_repository.dart';

/// Stand-ins for the repositories. Because every ViewModel asks for the
/// interface, a test can hand it one of these and drive the whole screen
/// logic with no network, no real clock and no waiting.

final day = DateTime.utc(2026, 10, 14);

WorkstationSlot aSlot({
  int id = 1,
  SlotStatus status = SlotStatus.available,
  DateTime? heldUntil,
  int hour = 9,
}) {
  return WorkstationSlot(
    id: id,
    startsAt: DateTime.utc(2026, 10, 14, hour),
    endsAt: DateTime.utc(2026, 10, 14, hour + 1),
    status: status,
    heldUntil: heldUntil,
  );
}

/// A hold whose clock agrees with the device's (no offset).
SlotHold aHold({int slotId = 1, required DateTime expiresAt, Duration offset = Duration.zero}) {
  return SlotHold(slotId: slotId, expiresAt: expiresAt, serverClockOffset: offset);
}

Workstation aWorkstation({int id = 1, String code = 'WS-01', bool isActive = true}) {
  return Workstation(id: id, name: 'Workstation $id', code: code, location: 'Building A', isActive: isActive);
}

Order anOrder({int id = 1, OrderStatus status = OrderStatus.pending}) {
  return Order(
    id: id,
    orderNumber: 'ORD-$id',
    customerName: 'Rahim',
    status: status,
    createdAt: DateTime.utc(2026, 10, 14),
  );
}

/// Always asks for "0 ms of jitter", so polling happens exactly every 5 seconds.
class ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

class FakeBookingRepository implements BookingRepository {
  List<WorkstationSlot> slotsResult = [];
  Failure? slotsFailure;
  Future<List<WorkstationSlot>> Function(int workstationId, DateTime day)? onSlots;
  int slotsCalls = 0;

  Future<SlotHold> Function(int slotId)? onHold;
  int holdCalls = 0;

  final released = <int>[];

  Future<Order> Function(int slotId, String customerName, String? notes)? onBook;
  final booked = <({int slotId, String customerName, String? notes})>[];

  @override
  Future<List<WorkstationSlot>> slots(int workstationId, DateTime day) async {
    slotsCalls++;
    if (onSlots != null) return onSlots!(workstationId, day);
    if (slotsFailure != null) throw slotsFailure!;
    return slotsResult;
  }

  @override
  Future<SlotHold> holdSlot(int slotId) async {
    holdCalls++;
    final handler = onHold;
    if (handler == null) throw StateError('onHold was not set for this test');
    return handler(slotId);
  }

  @override
  Future<void> releaseSlot(int slotId) async {
    released.add(slotId);
  }

  @override
  Future<Order> bookSlot({required int slotId, required String customerName, String? notes}) async {
    booked.add((slotId: slotId, customerName: customerName, notes: notes));
    final handler = onBook;
    return handler == null ? anOrder() : handler(slotId, customerName, notes);
  }

  @override
  Future<List<Order>> orders({OrderStatus? status, int? workstationId}) async => [];

  @override
  Future<List<Order>> ordersForWorkstation(int workstationId) async => [];

  @override
  Future<Order> order(int id) async => anOrder(id: id);

  @override
  Future<Order> updateStatus(int id, OrderStatus status) async => anOrder(id: id, status: status);

  @override
  Future<void> deleteOrder(int id) async {}
}

class FakeAuthRepository implements AuthRepository {
  bool hasSession = false;
  AppUser? user = const AppUser(id: 1, name: 'Momin', email: 'momin@example.com');
  Failure? currentUserFailure;
  Failure? loginFailure;
  Failure? logoutFailure;

  int currentUserCalls = 0;
  int clearCalls = 0;
  int logoutCalls = 0;

  final _expired = StreamController<void>.broadcast();

  /// Pretend both tokens were rejected mid-use.
  void expireSession() => _expired.add(null);

  @override
  Future<bool> hasStoredSession() async => hasSession;

  @override
  Future<AppUser> currentUser() async {
    currentUserCalls++;
    if (currentUserFailure != null) throw currentUserFailure!;
    return user!;
  }

  @override
  Future<AppUser> login({required String email, required String password}) async {
    if (loginFailure != null) throw loginFailure!;
    return user!;
  }

  @override
  Future<AppUser> register({required String name, required String email, required String password}) async {
    return user!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutFailure != null) throw logoutFailure!;
  }

  @override
  Future<void> clearSession() async {
    clearCalls++;
  }

  @override
  Stream<void> get sessionExpired => _expired.stream;
}

class FakeWorkstationRepository implements WorkstationRepository {
  List<Workstation> items = [];
  Failure? listFailure;
  Failure? createFailure;
  Failure? setActiveFailure;

  @override
  Future<List<Workstation>> list() async {
    if (listFailure != null) throw listFailure!;
    return items;
  }

  @override
  Future<Workstation> create({required String name, required String code, required String location}) async {
    if (createFailure != null) throw createFailure!;
    return Workstation(id: 99, name: name, code: code, location: location, isActive: true);
  }

  @override
  Future<Workstation> setActive(int id, {required bool isActive}) async {
    if (setActiveFailure != null) throw setActiveFailure!;
    final current = items.firstWhere((w) => w.id == id);
    return Workstation(
      id: current.id,
      name: current.name,
      code: current.code,
      location: current.location,
      isActive: isActive,
    );
  }
}
