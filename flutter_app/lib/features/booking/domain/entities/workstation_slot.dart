/// How a slot looks to the current user.
enum SlotStatus {
  available,

  /// Another user is on the confirm screen for it right now. Temporary: it
  /// frees up again if they leave or take too long.
  held,

  /// The current user is the one on the confirm screen.
  heldByYou,

  /// A non-cancelled order owns it.
  booked,
}

class WorkstationSlot {
  const WorkstationSlot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.heldUntil,
  });

  final int id;
  final DateTime startsAt;
  final DateTime endsAt;
  final SlotStatus status;

  /// For held / heldByYou: the latest moment the hold lapses on its own.
  final DateTime? heldUntil;

  bool get isAvailable => status == SlotStatus.available;

  /// Tapping should start a booking. The user's own hold counts: they can resume it.
  bool get canSelect => status == SlotStatus.available || status == SlotStatus.heldByYou;

  bool get isHeldByAnother => status == SlotStatus.held;
}
