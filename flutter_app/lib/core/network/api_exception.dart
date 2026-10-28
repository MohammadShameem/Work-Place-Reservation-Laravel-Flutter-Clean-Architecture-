/// Wraps a non-2xx response from the Laravel API in a shape the UI can show
/// directly: a human message, plus field-level validation errors when the
/// API returned a 422 (`{"message": "...", "errors": {"field": ["..."]}}`).
///
/// Conflicts about a slot (409) also carry a machine-readable [code]
/// (`slot_held` = someone else is on it right now, may free up soon;
/// `slot_booked` = taken until that order is cancelled) and, for held,
/// [retryAfter] seconds.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, List<String>>? errors;
  final String? code;
  final int? retryAfter;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
    this.code,
    this.retryAfter,
  });

  factory ApiException.fromResponseBody(int statusCode, dynamic body) {
    var message = 'Something went wrong (HTTP $statusCode).';
    Map<String, List<String>>? errors;
    String? code;
    int? retryAfter;

    if (body is Map<String, dynamic>) {
      if (body['message'] is String) {
        message = body['message'] as String;
      }
      if (body['code'] is String) {
        code = body['code'] as String;
      }
      if (body['retry_after'] is num) {
        retryAfter = (body['retry_after'] as num).toInt();
      }

      final rawErrors = body['errors'];
      if (rawErrors is Map) {
        errors = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List ? value.map((e) => e.toString()).toList() : <String>[value.toString()],
          ),
        );
      }
    }

    return ApiException(
      statusCode: statusCode,
      message: message,
      errors: errors,
      code: code,
      retryAfter: retryAfter,
    );
  }

  bool get isUnauthenticated => statusCode == 401;

  bool get isValidationError => statusCode == 422;

  bool get isConflict => statusCode == 409;

  /// Someone else is on this slot right now; it may free up shortly.
  bool get isSlotHeld => code == 'slot_held';

  /// The slot has been booked; it stays taken until that order is cancelled.
  bool get isSlotBooked => code == 'slot_booked';

  /// All field errors flattened into one list, for a simple error banner.
  List<String> get allMessages {
    final map = errors;
    if (map == null || map.isEmpty) return [message];
    return map.values.expand((messages) => messages).toList();
  }

  @override
  String toString() => message;
}
