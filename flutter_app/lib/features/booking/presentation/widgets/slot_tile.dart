import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/workstation_slot.dart';

/// One time slot in the picker. The look changes with who has it:
/// available (tap to book), being selected by someone else (temporary),
/// held for you, or booked.
class SlotTile extends StatelessWidget {
  const SlotTile({super.key, required this.slot, this.onTap});

  final WorkstationSlot slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('h:mm a');

    final (background, foreground, icon, label) = switch (slot.status) {
      SlotStatus.available => (colors.primaryContainer, colors.onPrimaryContainer, Icons.check_circle_outline, 'Available'),
      SlotStatus.heldByYou => (colors.secondaryContainer, colors.onSecondaryContainer, Icons.timer_outlined, 'Held for you'),
      SlotStatus.held => (colors.tertiaryContainer, colors.onTertiaryContainer, Icons.hourglass_top, 'Being selected'),
      SlotStatus.booked => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.block, 'Booked'),
    };

    // Shown exactly as the server sends them, same as the orders screens do.
    final range = '${timeFormat.format(slot.startsAt)} - ${timeFormat.format(slot.endsAt)}';

    return Semantics(
      button: onTap != null,
      label: '$range, $label',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            // Each line shrinks to fit rather than wrapping or running over: the
            // tile's width changes with the window, and a wrapped line would
            // need more height than the grid gives it (see SlotGrid).
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(range, style: TextStyle(fontWeight: FontWeight.w600, color: foreground)),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: foreground),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(fontSize: 12, color: foreground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
