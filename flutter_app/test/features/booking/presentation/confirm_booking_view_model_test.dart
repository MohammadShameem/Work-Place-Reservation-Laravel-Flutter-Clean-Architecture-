import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/core/di/core_providers.dart';
import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/booking/domain/entities/slot_hold.dart';
import 'package:order_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:order_app/features/booking/presentation/viewmodel/confirm_booking_view_model.dart';

import '../../../support/fakes.dart';

final start = DateTime.utc(2026, 10, 14, 9);

/// A hold that lapses [seconds] after the (fake) clock's start.
SlotHold holdFor(int seconds, {int slotId = 7}) {
  return aHold(slotId: slotId, expiresAt: start.add(Duration(seconds: seconds)));
}

class Harness {
  Harness(FakeAsync async, this.repo, {int holdSeconds = 180})
    : args = ConfirmBookingArgs(slotId: 7, hold: holdFor(holdSeconds)) {
    final clock = async.getClock(start);

    container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => clock.now()),
      ],
      retry: (_, _) => null,
    );
    provider = confirmBookingViewModelProvider(args);
    container.listen(provider, (_, _) {});
    container.listen(provider.select((s) => s.event), (_, event) {
      if (event != null) events.add(event);
    });
  }

  final FakeBookingRepository repo;
  final ConfirmBookingArgs args;
  late final ProviderContainer container;
  late final NotifierProvider<ConfirmBookingViewModel, ConfirmBookingState> provider;
  final events = <ConfirmBookingEvent>[];

  ConfirmBookingState get state => container.read(provider);

  ConfirmBookingViewModel get vm => container.read(provider.notifier);

  void dispose() => container.dispose();
}

void main() {
  late FakeBookingRepository repo;

  setUp(() => repo = FakeBookingRepository());

  group('countdown', () {
    test('starts from what is left and ticks down each second', () {
      fakeAsync((async) {
        final h = Harness(async, repo);
        expect(h.state.remaining, const Duration(seconds: 180));

        async.elapse(const Duration(seconds: 60));
        expect(h.state.remaining, const Duration(seconds: 120));
        h.dispose();
      });
    });

    test('warns in the last 30 seconds, not before', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        async.elapse(const Duration(seconds: 149));
        expect(h.state.isRunningOut, isFalse);

        async.elapse(const Duration(seconds: 1)); // 30s left
        expect(h.state.isRunningOut, isTrue);
        h.dispose();
      });
    });

    test('a phone with a wrong clock still counts down correctly', () {
      fakeAsync((async) {
        // The device thinks it is 2.5 hours later than the server; the offset
        // recorded when the hold was issued corrects for that.
        final skewed = ConfirmBookingArgs(
          slotId: 7,
          hold: aHold(
            slotId: 7,
            expiresAt: start.add(const Duration(seconds: 180)),
            offset: const Duration(hours: -2, minutes: -30),
          ),
        );
        final clock = async.getClock(start.add(const Duration(hours: 2, minutes: 30)));
        final container = ProviderContainer(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repo),
            nowProvider.overrideWithValue(() => clock.now()),
          ],
        );
        final provider = confirmBookingViewModelProvider(skewed);
        container.listen(provider, (_, _) {});

        expect(container.read(provider).remaining, const Duration(seconds: 180));
        container.dispose();
      });
    });
  });

  group('running out of time', () {
    test('asks once what to do when the countdown reaches zero', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        async.elapse(const Duration(seconds: 179));
        expect(h.events, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(h.events.single, isA<HoldExpired>());

        async.elapse(const Duration(seconds: 30));
        expect(h.events, hasLength(1), reason: 'no repeats');
        h.dispose();
      });
    });

    test('"try again" gets a fresh hold and the countdown restarts', () {
      fakeAsync((async) {
        repo.onHold = (_) async => aHold(slotId: 7, expiresAt: start.add(const Duration(seconds: 360)));
        final h = Harness(async, repo);
        async.elapse(const Duration(seconds: 180));

        h.vm.retryHold();
        async.flushMicrotasks();

        expect(repo.holdCalls, 1);
        expect(h.state.slotLost, isFalse);
        expect(h.state.remaining, const Duration(seconds: 180));

        async.elapse(const Duration(seconds: 60));
        expect(h.state.remaining, const Duration(seconds: 120));
        h.dispose();
      });
    });

    test('"try again" when someone else took it ends the attempt with their reason', () {
      fakeAsync((async) {
        repo.onHold = (_) async => throw const SlotHeldFailure('Another user is selecting this slot.');
        final h = Harness(async, repo);
        async.elapse(const Duration(seconds: 180));

        h.vm.retryHold();
        async.flushMicrotasks();

        expect(h.state.slotLost, isTrue);
        expect(h.state.errorMessage, 'Another user is selecting this slot.');
        h.dispose();
      });
    });
  });

  group('confirming', () {
    test('books the slot with what was typed, then closes as booked', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        h.vm.submit(customerName: 'Rahim', notes: 'Rush');
        async.flushMicrotasks();

        expect(repo.booked.single, (slotId: 7, customerName: 'Rahim', notes: 'Rush'));
        final finished = h.events.single as Finished;
        expect(finished.booked, isTrue);
        h.dispose();
      });
    });

    test('someone else got there first: the attempt is over and the reason is shown', () {
      fakeAsync((async) {
        repo.onBook = (_, _, _) async => throw const SlotHeldFailure('Another user is selecting this slot.');
        final h = Harness(async, repo);

        h.vm.submit(customerName: 'Rahim');
        async.flushMicrotasks();

        expect(h.state.slotLost, isTrue);
        expect(h.state.isSubmitting, isFalse);
        expect(h.state.errorMessage, 'Another user is selecting this slot.');
        expect(h.events, isEmpty);
        h.dispose();
      });
    });

    test('a slot that was booked meanwhile is handled the same way', () {
      fakeAsync((async) {
        repo.onBook = (_, _, _) async => throw const SlotBookedFailure('Already booked.');
        final h = Harness(async, repo);

        h.vm.submit(customerName: 'Rahim');
        async.flushMicrotasks();

        expect(h.state.slotLost, isTrue);
        h.dispose();
      });
    });

    test('a validation problem is shown but the user can fix it and go again', () {
      fakeAsync((async) {
        repo.onBook = (_, _, _) async => throw const ValidationFailure('The customer name field is required.');
        final h = Harness(async, repo);

        h.vm.submit(customerName: '');
        async.flushMicrotasks();

        expect(h.state.slotLost, isFalse);
        expect(h.state.isSubmitting, isFalse);
        expect(h.state.errorMessage, 'The customer name field is required.');
        h.dispose();
      });
    });

    test('once the slot is lost, the button just leaves', () {
      fakeAsync((async) {
        repo.onBook = (_, _, _) async => throw const SlotBookedFailure('Already booked.');
        final h = Harness(async, repo);
        h.vm.submit(customerName: 'Rahim');
        async.flushMicrotasks();
        expect(repo.booked, hasLength(1));

        h.vm.submit(customerName: 'Rahim');
        async.flushMicrotasks();

        expect(repo.booked, hasLength(1), reason: 'does not try to book again');
        expect((h.events.single as Finished).booked, isFalse);
        h.dispose();
      });
    });
  });

  group('giving the slot back', () {
    test('leaving without booking releases the hold', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        h.dispose(); // the screen was closed
        async.flushMicrotasks();

        expect(repo.released, [7]);
      });
    });

    test('after booking there is nothing to release', () {
      fakeAsync((async) {
        final h = Harness(async, repo);
        h.vm.submit(customerName: 'Rahim');
        async.flushMicrotasks();

        h.dispose();
        async.flushMicrotasks();

        expect(repo.released, isEmpty);
      });
    });

    test('the countdown stops when the screen closes', () {
      fakeAsync((async) {
        final h = Harness(async, repo);

        h.dispose();
        async.elapse(const Duration(seconds: 600)); // would have expired long ago

        expect(h.events, isEmpty);
      });
    });
  });
}
