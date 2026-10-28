import 'package:intl/intl.dart';

import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/slot_hold.dart';
import '../../domain/entities/workstation_slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_data_source.dart';
import '../models/booking_mappers.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._remote, {required this.now});

  final BookingRemoteDataSource _remote;
  final DateTime Function() now;

  @override
  Future<List<WorkstationSlot>> slots(int workstationId, DateTime day) {
    return guardFailures(() async {
      final rows = await _remote.slots(workstationId, date: DateFormat('yyyy-MM-dd').format(day));
      return rows.map(SlotMapper.fromJson).toList();
    });
  }

  @override
  Future<SlotHold> holdSlot(int slotId) {
    return guardFailures(() async {
      return SlotHoldMapper.fromJson(await _remote.hold(slotId), deviceNow: now());
    });
  }

  @override
  Future<void> releaseSlot(int slotId) => guardFailures(() => _remote.release(slotId));

  @override
  Future<Order> bookSlot({required int slotId, required String customerName, String? notes}) {
    return guardFailures(() async {
      final json = await _remote.book(slotId: slotId, customerName: customerName, notes: notes);
      return OrderMapper.fromJson(json);
    });
  }

  @override
  Future<List<Order>> orders({OrderStatus? status, int? workstationId}) {
    return guardFailures(() async {
      final rows = await _remote.orders(
        status: status == null ? null : OrderStatusApi.toApi(status),
        workstationId: workstationId,
      );
      return rows.map(OrderMapper.fromJson).toList();
    });
  }

  @override
  Future<List<Order>> ordersForWorkstation(int workstationId) {
    return guardFailures(() async {
      return (await _remote.ordersForWorkstation(workstationId)).map(OrderMapper.fromJson).toList();
    });
  }

  @override
  Future<Order> order(int id) {
    return guardFailures(() async => OrderMapper.fromJson(await _remote.order(id)));
  }

  @override
  Future<Order> updateStatus(int id, OrderStatus status) {
    return guardFailures(() async {
      return OrderMapper.fromJson(await _remote.updateStatus(id, OrderStatusApi.toApi(status)));
    });
  }

  @override
  Future<void> deleteOrder(int id) => guardFailures(() => _remote.deleteOrder(id));
}
