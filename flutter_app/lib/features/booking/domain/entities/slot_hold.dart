/// A short reservation of one slot while the user fills in the confirm screen.
class SlotHold {
  const SlotHold({
    required this.slotId,
    required this.expiresAt,
    required this.serverClockOffset,
  });

  final int slotId;
  final DateTime expiresAt;

  /// Server clock minus this device's clock, measured when the hold was
  /// issued. The countdown uses it so a phone with a wrong clock still shows
  /// the right time left (the server alone decides when the hold lapses).
  final Duration serverClockOffset;

  /// Time left by the server's clock, given what this device thinks the time
  /// is. Zero or negative means it has lapsed.
  Duration remaining(DateTime deviceNow) {
    return expiresAt.difference(deviceNow.toUtc().add(serverClockOffset));
  }
}
