import '../../domain/entities/app_user.dart';

/// JSON <-> entity translation. The only place that knows the API's field names.
abstract final class UserMapper {
  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}
