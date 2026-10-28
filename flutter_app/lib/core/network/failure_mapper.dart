import '../error/failure.dart';
import 'api_exception.dart';

/// HTTP error -> the app's own [Failure]. The one place that knows which
/// status code / `code` field means what.
Failure failureFromApiException(ApiException e) {
  if (e.isSlotHeld) return SlotHeldFailure(e.message, retryAfter: e.retryAfter);
  if (e.isSlotBooked) return SlotBookedFailure(e.message);
  if (e.isUnauthenticated) return UnauthenticatedFailure(e.message);
  if (e.isValidationError) {
    return ValidationFailure(e.allMessages.join('\n'), fieldErrors: e.errors ?? const {});
  }
  return ServerFailure(e.message, statusCode: e.statusCode);
}

/// Runs [body] and makes sure the only thing that can come out of it is a
/// [Failure]. Repositories wrap every call in this.
///
/// Only `Exception`s are translated. A programming `Error` (a bad cast, a
/// null where there should be none) is a bug and is left to crash loudly
/// rather than be disguised as "could not reach the server".
Future<T> guardFailures<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on Failure {
    rethrow;
  } on ApiException catch (e) {
    throw failureFromApiException(e);
  } on Exception {
    throw const NetworkFailure();
  }
}
