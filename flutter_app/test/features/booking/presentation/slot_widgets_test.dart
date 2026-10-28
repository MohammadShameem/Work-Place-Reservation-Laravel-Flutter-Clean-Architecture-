import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/features/booking/domain/entities/order_status.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';
import 'package:order_app/features/booking/presentation/widgets/slot_grid.dart';
import 'package:order_app/features/booking/presentation/widgets/slot_tile.dart';
import 'package:order_app/features/booking/presentation/widgets/status_chip.dart';

import '../../../support/fakes.dart';

void main() {
  group('SlotTile', () {
    Future<void> pump(WidgetTester tester, WorkstationSlot slot, VoidCallback? onTap) {
      return tester.pumpWidget(MaterialApp(home: Scaffold(body: SlotTile(slot: slot, onTap: onTap))));
    }

    testWidgets('shows a different label for each status', (tester) async {
      for (final (status, label) in [
        (SlotStatus.available, 'Available'),
        (SlotStatus.held, 'Being selected'),
        (SlotStatus.heldByYou, 'Held for you'),
        (SlotStatus.booked, 'Booked'),
      ]) {
        await pump(tester, aSlot(status: status), () {});
        expect(find.text(label), findsOneWidget, reason: '$status');
        expect(find.text('9:00 AM - 10:00 AM'), findsOneWidget);
      }
    });

    testWidgets('tapping calls back only when the screen allows it', (tester) async {
      var taps = 0;

      await pump(tester, aSlot(), () => taps++);
      await tester.tap(find.byType(SlotTile));
      expect(taps, 1);

      await pump(tester, aSlot(status: SlotStatus.booked), null);
      await tester.tap(find.byType(SlotTile));
      expect(taps, 1);
    });
  });

  group('SlotGrid', () {
    testWidgets('a booked slot is not tappable, but one someone else is on still is (to explain why)', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlotGrid(
              slots: [
                aSlot(id: 1),
                aSlot(id: 2, status: SlotStatus.held, hour: 10),
                aSlot(id: 3, status: SlotStatus.booked, hour: 11),
              ],
              onSlotTap: (slot) => tapped.add(slot.id),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Available'));
      await tester.tap(find.text('Being selected'));
      await tester.tap(find.text('Booked'));

      expect(tapped, [1, 2]);
    });

    // The grid sizes its columns from the window width, so the tile width — and
    // with it how much room the text gets — changes with every resize. Try the
    // widths real devices and browser windows land on, plus a bigger text size.
    const widths = [320.0, 360.0, 412.0, 600.0, 800.0, 1024.0, 1190.0, 1200.0, 1280.0, 1440.0, 1920.0];

    for (final textScale in [1.0, 1.5]) {
      for (final width in widths) {
        testWidgets('does not overflow at ${width.toInt()}px wide, text x$textScale', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: SlotGrid(
                    slots: [
                      for (var i = 1; i <= 8; i++)
                        aSlot(id: i, status: SlotStatus.values[i % 4], hour: 8 + i),
                    ],
                    onSlotTap: (_) {},
                  ),
                ),
              ),
            ),
          );

          // A RenderFlex overflow is reported as a Flutter error, which fails the test.
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('StatusChip shows the human label for a status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusChip(status: OrderStatus.inProgress))),
    );

    expect(find.text('In Progress'), findsOneWidget);
  });
}
