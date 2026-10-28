import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/features/booking/domain/entities/order_status.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';

import '../../../support/fakes.dart';

/// The business rules, tested as plain Dart: no widgets, no network, no JSON.
void main() {
  group('OrderStatus rules', () {
    test('an order moves forward one step at a time and can be cancelled until completed', () {
      expect(OrderStatus.pending.nextOptions, [OrderStatus.inProgress, OrderStatus.cancelled]);
      expect(OrderStatus.inProgress.nextOptions, [OrderStatus.completed, OrderStatus.cancelled]);
    });

    test('completed and cancelled are final', () {
      expect(OrderStatus.completed.nextOptions, isEmpty);
      expect(OrderStatus.cancelled.nextOptions, isEmpty);
      expect(OrderStatus.completed.isClosed, isTrue);
      expect(OrderStatus.cancelled.isClosed, isTrue);
      expect(OrderStatus.pending.isClosed, isFalse);
      expect(OrderStatus.inProgress.isClosed, isFalse);
    });

    test('only a pending or cancelled order can be deleted', () {
      expect(OrderStatus.pending.canBeDeleted, isTrue);
      expect(OrderStatus.cancelled.canBeDeleted, isTrue);
      expect(OrderStatus.inProgress.canBeDeleted, isFalse);
      expect(OrderStatus.completed.canBeDeleted, isFalse);
    });
  });

  group('WorkstationSlot rules', () {
    test('only an available slot, or your own hold, can be selected', () {
      expect(aSlot(status: SlotStatus.available).canSelect, isTrue);
      expect(aSlot(status: SlotStatus.heldByYou).canSelect, isTrue);
      expect(aSlot(status: SlotStatus.held).canSelect, isFalse);
      expect(aSlot(status: SlotStatus.booked).canSelect, isFalse);
    });

    test('"available" means free for anyone, which your own hold is not', () {
      expect(aSlot(status: SlotStatus.available).isAvailable, isTrue);
      expect(aSlot(status: SlotStatus.heldByYou).isAvailable, isFalse);
      expect(aSlot(status: SlotStatus.held).isAvailable, isFalse);
    });

    test('a slot held by someone else is the only one that is "held by another"', () {
      expect(aSlot(status: SlotStatus.held).isHeldByAnother, isTrue);
      expect(aSlot(status: SlotStatus.heldByYou).isHeldByAnother, isFalse);
    });
  });

  group('SlotHold.remaining', () {
    final expiresAt = DateTime.utc(2026, 10, 14, 9, 3);

    test('is the time left when device and server agree', () {
      final hold = aHold(expiresAt: expiresAt);

      expect(hold.remaining(DateTime.utc(2026, 10, 14, 9)), const Duration(minutes: 3));
      expect(hold.remaining(DateTime.utc(2026, 10, 14, 9, 2)), const Duration(minutes: 1));
    });

    test('is zero or negative once it has lapsed', () {
      final hold = aHold(expiresAt: expiresAt);

      expect(hold.remaining(expiresAt), Duration.zero);
      expect(hold.remaining(expiresAt.add(const Duration(seconds: 5))).isNegative, isTrue);
    });

    test('follows the server\'s clock, not the phone\'s', () {
      // The phone runs 2h30 fast, which was measured when the hold was issued.
      final hold = aHold(expiresAt: expiresAt, offset: const Duration(hours: -2, minutes: -30));
      final phoneNow = DateTime.utc(2026, 10, 14, 11, 30);

      expect(hold.remaining(phoneNow), const Duration(minutes: 3));
      expect(hold.remaining(phoneNow.add(const Duration(minutes: 1))), const Duration(minutes: 2));
    });
  });
}
