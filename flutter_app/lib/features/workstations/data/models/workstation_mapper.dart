import '../../domain/entities/workstation.dart';

/// JSON -> entity. The only place that knows the API's field names.
abstract final class WorkstationMapper {
  static Workstation fromJson(Map<String, dynamic> json) => Workstation(
    id: json['id'] as int,
    name: json['name'] as String,
    code: json['code'] as String,
    location: json['location'] as String,
    isActive: json['is_active'] as bool,
    ordersCount: json['orders_count'] as int?,
  );
}
