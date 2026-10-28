class Workstation {
  const Workstation({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    required this.isActive,
    this.ordersCount,
  });

  final int id;
  final String name;
  final String code;
  final String location;
  final bool isActive;

  /// Only present when the list was asked for with counts.
  final int? ordersCount;

  /// Can people still book it? (A deactivated workstation is kept, not bookable.)
  bool get isBookable => isActive;
}
