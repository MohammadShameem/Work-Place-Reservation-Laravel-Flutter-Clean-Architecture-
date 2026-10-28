import 'package:flutter/material.dart';

import '../../domain/entities/workstation_slot.dart';
import 'slot_tile.dart';

/// The grid of time slots on the picker screen.
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.onSlotTap});

  final List<WorkstationSlot> slots;
  final ValueChanged<WorkstationSlot> onSlotTap;

  @override
  Widget build(BuildContext context) {
    // A fixed height, not an aspect ratio. With an aspect ratio the height
    // follows the width, so a window just wide enough to squeeze in one more
    // column made every tile shorter than its text needed. Here the height
    // depends only on what the tile contains: its padding and gap (fixed) plus
    // two lines of text, which grow with the user's text-size setting.
    final tileHeight = 28 + MediaQuery.textScalerOf(context).scale(37);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: tileHeight,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        // A slot someone else is on is still tappable — to explain why it isn't free.
        final tappable = slot.canSelect || slot.isHeldByAnother;
        return SlotTile(slot: slot, onTap: tappable ? () => onSlotTap(slot) : null);
      },
    );
  }
}
