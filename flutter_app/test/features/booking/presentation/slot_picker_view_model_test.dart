import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/core/di/core_providers.dart';
import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';
import 'package:order_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:order_app/features/booking/presentation/viewmodel/slot_picker_view_model.dart';

import '../../../support/fakes.dart';

/// Drives the slot picker's ViewModel with a fake repository, a fake clock
/// and fake timers: "five seconds later" takes no time at all.
class Harness {
  Harness(FakeAsync async, this.repo, {int workstationId = 4}) : provider = slotPickerViewModelProvider(workstationId) {
    final clock = async.getClock(DateTime.utc(2026, 10, 14, 9));

    container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => clock.now()),
        randomProvider.overrideWithValue(ZeroRandom()),
      ],
      retry: (_, _) => null,
    );
    container.listen(provider, (_, _) {}); // keep the ViewModel alive, like a screen would
    container.listen(provider.select((s) => s.event), (_, event) {
      if (event != null) events.add(event);
    });
    async.flushMicrotasks(); // build + first fetch
  }

  final FakeBookingRepository repo;
  final NotifierProvider<SlotPickerViewModel, SlotPickerState> provider;
  late final ProviderContainer container;
  final events = <SlotPickerEvent>[];

  SlotPickerState get state => container.read(provider);

  SlotPickerViewModel get vm => container.read(provider.notifier);

  void dispose() => container.dispose();
}

void main() {
  late FakeBookingRepository repo;

  setUp(() {
    repo = FakeBookingRepository()..slotsResult = [aSlot(id: 1), aSlot(id: 2, hour: 10)];
  });

  group('loading', () {
    test('loads the day on start', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        expect(h.state.isLoading, isFalse);
        expect(h.state.slots, hasLength(2));
        expect(repo.slotsCalls, 1);
        h.dispose();
      });
    });

    test('a failed first load is an error (with nothing to show), and retry loads it', () {
      fakeAsync((async) {
        repo.slotsFailure = const NetworkFailure();
        final h = Harness(async, repo);

        expect(h.state.slots, isNull);
        expect(h.state.error, isA<NetworkFailure>());

        repo.slotsFailure = null;
        h.vm.retry();
        async.flushMicrotasks();

        expect(h.state.slots, hasLength(2));
        expect(h.state.error, isNull);
        h.dispose();
      });
    });

    test('changing the day loads that day, and a late answer for the old day is ignored', () {
      fakeAsync((async) {
        final firstDay = Completer<List<WorkstationSlot>>();
        final secondDay = Completer<List<WorkstationSlot>>();
        final pending = [firstDay, secondDay];
        repo.onSlots = (_, _) => pending.removeAt(0).future;

        final h = Harness(async, repo);
        h.vm.selectDay(DateTime.utc(2026, 10, 15));
        async.flushMicrotasks();

        secondDay.complete([aSlot(id: 20)]);
        async.flushMicrotasks();
        firstDay.complete([aSlot(id: 10)]); // the slow, stale answer arrives last
        async.flushMicrotasks();

        expect(h.state.slots!.map((s) => s.id), [20]);
        h.dispose();
      });
    });
  });

  group('polling', () {
    test('asks again every 5 seconds', () {
      fakeAsync((async) {
        final h = Harness(async, repo);
        expect(repo.slotsCalls, 1);

        async.elapse(const Duration(seconds: 4));
        expect(repo.slotsCalls, 1);

        async.elapse(const Duration(seconds: 1));
        expect(repo.slotsCalls, 2);

        async.elapse(const Duration(seconds: 5));
        expect(repo.slotsCalls, 3);
        h.dispose();
      });
    });

    test('a slot another user takes shows up on the next poll, and frees up again', () {
      fakeAsync((async) {
        final h = Harness(async, repo);
        expect(h.state.slots!.first.status, SlotStatus.available);

        repo.slotsResult = [aSlot(id: 1, status: SlotStatus.held), aSlot(id: 2, hour: 10)];
        async.elapse(const Duration(seconds: 5));
        expect(h.state.slots!.first.status, SlotStatus.held);

        repo.slotsResult = [aSlot(id: 1), aSlot(id: 2, hour: 10)];
        async.elapse(const Duration(seconds: 5));
        expect(h.state.slots!.first.status, SlotStatus.available);
        h.dispose();
      });
    });

    test('stops while the app is in the background and catches up the moment it returns', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        h.vm.setForeground(false);
        async.elapse(const Duration(seconds: 30));
        expect(repo.slotsCalls, 1);

        h.vm.setForeground(true);
        async.flushMicrotasks();
        expect(repo.slotsCalls, 2);
        h.dispose();
      });
    });

    test('a failing refresh keeps the slots on screen and says so, then recovers', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        repo.slotsFailure = const NetworkFailure();
        async.elapse(const Duration(seconds: 5));
        expect(h.state.slots, hasLength(2), reason: 'older data stays visible');
        expect(h.state.error, isNull, reason: 'not an error screen');
        expect(h.state.refreshFailing, isTrue);

        repo.slotsFailure = null;
        async.elapse(const Duration(seconds: 5));
        expect(h.state.refreshFailing, isFalse);
        h.dispose();
      });
    });

    test('stops for good when the screen goes away', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        h.dispose();
        async.elapse(const Duration(seconds: 60));

        expect(repo.slotsCalls, 1);
      });
    });
  });

  group('tapping a slot', () {
    test('a free slot is held first, then the confirm screen is requested', () {
      fakeAsync((async) {
        final hold = aHold(slotId: 1, expiresAt: DateTime.utc(2026, 10, 14, 9, 3));
        repo.onHold = (_) async => hold;
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect(repo.holdCalls, 1);
        final event = h.events.single as OpenConfirm;
        expect(event.slot.id, 1);
        expect(event.hold, same(hold));
        h.dispose();
      });
    });

    test('polling pauses while the confirm screen is open and resumes (with a refresh) when it closes', () {
      fakeAsync((async) {
        repo.onHold = (_) async => aHold(expiresAt: DateTime.utc(2026, 10, 14, 9, 3));
        final h = Harness(async, repo);
        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();
        final callsBefore = repo.slotsCalls;

        async.elapse(const Duration(seconds: 20));
        expect(repo.slotsCalls, callsBefore, reason: 'the confirm screen keeps the hold alive itself');

        h.vm.confirmClosed(booked: false);
        async.flushMicrotasks();
        expect(repo.slotsCalls, callsBefore + 1, reason: 'the slot may have changed while away');

        async.elapse(const Duration(seconds: 5));
        expect(repo.slotsCalls, callsBefore + 2);
        h.dispose();
      });
    });

    test('a slot someone else is on is explained without asking the server', () {
      fakeAsync((async) {
        repo.slotsResult = [aSlot(id: 1, status: SlotStatus.held, heldUntil: DateTime.utc(2026, 10, 14, 9, 2, 30))];
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect(repo.holdCalls, 0);
        final message = h.events.single as ShowSlotMessage;
        expect(message.kind, SlotMessageKind.held);
        expect(message.text, contains('Another user is selecting this slot right now'));
        expect(message.text, contains('may become available again shortly'));
        expect(message.text, contains('within about 3 min'));
        h.dispose();
      });
    });

    test('a booked slot does nothing', () {
      fakeAsync((async) {
        repo.slotsResult = [aSlot(id: 1, status: SlotStatus.booked)];
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect(repo.holdCalls, 0);
        expect(h.events, isEmpty);
        h.dispose();
      });
    });

    test('your own hold can be resumed', () {
      fakeAsync((async) {
        repo.slotsResult = [aSlot(id: 1, status: SlotStatus.heldByYou)];
        repo.onHold = (_) async => aHold(expiresAt: DateTime.utc(2026, 10, 14, 9, 3));
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect(h.events.single, isA<OpenConfirm>());
        h.dispose();
      });
    });

    test('losing the race: the server says held, the user is told and the list refreshes at once', () {
      fakeAsync((async) {
        repo.onHold = (_) async => throw const SlotHeldFailure('Another user is selecting this slot.', retryAfter: 30);
        final h = Harness(async, repo);
        final callsBefore = repo.slotsCalls;

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        final message = h.events.single as ShowSlotMessage;
        expect(message.kind, SlotMessageKind.held);
        expect(message.text, 'Another user is selecting this slot.');
        expect(repo.slotsCalls, callsBefore + 1);
        expect(h.state.isHolding, isFalse);
        h.dispose();
      });
    });

    test('losing to a booking is reported as booked', () {
      fakeAsync((async) {
        repo.onHold = (_) async => throw const SlotBookedFailure('Already booked.');
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect((h.events.single as ShowSlotMessage).kind, SlotMessageKind.booked);
        h.dispose();
      });
    });

    test('no connection is reported as offline, and nothing is refetched', () {
      fakeAsync((async) {
        repo.onHold = (_) async => throw const NetworkFailure();
        final h = Harness(async, repo);
        final callsBefore = repo.slotsCalls;

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();

        expect((h.events.single as ShowSlotMessage).kind, SlotMessageKind.offline);
        expect(repo.slotsCalls, callsBefore);
        h.dispose();
      });
    });

    test('a second tap while the first is still waiting is ignored', () {
      fakeAsync((async) {
        final answer = Completer<dynamic>();
        repo.onHold = (_) async => await answer.future;
        final h = Harness(async, repo);
        final slot = h.state.slots!.first;

        h.vm.onSlotTap(slot);
        async.flushMicrotasks();
        expect(h.state.isHolding, isTrue);

        h.vm.onSlotTap(slot);
        async.flushMicrotasks();

        expect(repo.holdCalls, 1);
        answer.completeError(const NetworkFailure());
        async.flushMicrotasks();
        h.dispose();
      });
    });

    test('an event is cleared once the screen has handled it', () {
      fakeAsync((async) {
        repo.onHold = (_) async => throw const NetworkFailure();
        final h = Harness(async, repo);

        h.vm.onSlotTap(h.state.slots!.first);
        async.flushMicrotasks();
        expect(h.state.event, isNotNull);

        h.vm.consumeEvent();
        expect(h.state.event, isNull);
        h.dispose();
      });
    });
  });
}
