import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/core/di/core_providers.dart';
import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';
import 'package:order_app/features/booking/presentation/providers/booking_providers.dart';
import 'package:order_app/features/booking/presentation/view/slot_picker_page.dart';
import 'package:order_app/features/booking/presentation/widgets/slot_tile.dart';

import '../../../support/fakes.dart';

/// The whole slot-picker flow — page, ViewModel and (fake) repository wired
/// together through the same providers the real app uses.
void main() {
  late FakeBookingRepository repo;

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          bookingRepositoryProvider.overrideWithValue(repo),
          randomProvider.overrideWithValue(ZeroRandom()),
        ],
        child: MaterialApp(home: SlotPickerPage(workstation: aWorkstation(id: 4))),
      ),
    );
    await tester.pump(); // let the first load finish
  }

  /// Tear the page down inside the test so its timers are cancelled before the test ends.
  Future<void> closePicker(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  setUp(() {
    repo = FakeBookingRepository()
      ..slotsResult = [
        aSlot(id: 1),
        aSlot(id: 2, status: SlotStatus.held, hour: 10, heldUntil: DateTime.now().toUtc().add(const Duration(minutes: 2))),
        aSlot(id: 3, status: SlotStatus.booked, hour: 11),
      ];
  });

  testWidgets('shows each slot with its own state', (tester) async {
    await openPicker(tester);

    expect(find.text('Available'), findsWidgets);
    expect(find.text('Being selected'), findsOneWidget);
    expect(find.text('Booked'), findsWidgets);
    expect(repo.slotsCalls, 1);

    await closePicker(tester);
  });

  testWidgets('tapping a slot someone else is on explains that it may free up, and asks the server nothing', (tester) async {
    await openPicker(tester);

    await tester.tap(find.text('Being selected'));
    await tester.pump();

    expect(find.textContaining('Another user is selecting this slot right now'), findsOneWidget);
    expect(find.textContaining('may become available again shortly'), findsOneWidget);
    expect(repo.holdCalls, 0);

    await closePicker(tester);
  });

  testWidgets('tapping a free slot holds it and opens the confirm screen with a countdown', (tester) async {
    repo.onHold = (slotId) async => aHold(slotId: slotId, expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 3)), offset: Duration.zero);
    await openPicker(tester);

    await tester.tap(find.byType(SlotTile).first); // not the legend, which also says 'Available'
    await tester.pumpAndSettle();

    expect(repo.holdCalls, 1);
    expect(find.text('Confirm booking'), findsWidgets);
    expect(find.text('This slot is held for you while you confirm'), findsOneWidget);

    await closePicker(tester);
  });

  testWidgets('backing out of the confirm screen gives the slot back', (tester) async {
    repo.onHold = (slotId) async => aHold(slotId: slotId, expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 3)));
    await openPicker(tester);
    await tester.tap(find.byType(SlotTile).first); // not the legend, which also says 'Available'
    await tester.pumpAndSettle();
    expect(repo.released, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repo.released, [1]);

    await closePicker(tester);
  });

  testWidgets('losing the race shows the server\'s message right on the slot list', (tester) async {
    repo.onHold = (_) async => throw const SlotHeldFailure('Someone just took this slot.', retryAfter: 20);
    await openPicker(tester);

    await tester.tap(find.byType(SlotTile).first); // not the legend, which also says 'Available'
    await tester.pump();
    await tester.pump();

    expect(find.text('Someone just took this slot.'), findsOneWidget);
    expect(find.text('Confirm booking'), findsNothing, reason: 'never reached the form');

    await closePicker(tester);
  });

  testWidgets('a failed first load shows an error with a retry button that works', (tester) async {
    repo.slotsFailure = const NetworkFailure();
    await openPicker(tester);

    expect(find.text(const NetworkFailure().message), findsOneWidget);

    repo.slotsFailure = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Available'), findsWidgets);

    await closePicker(tester);
  });
}
