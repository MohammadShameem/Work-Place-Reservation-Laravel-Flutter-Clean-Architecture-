/// What can go wrong, in the app's own words.
///
/// The data layer turns transport errors (HTTP codes, dropped connections)
/// into one of these, so nothing above it ever has to know about HTTP: a
/// ViewModel just catches a [Failure] and shows its [message].
///
/// Pure Dart — no Flutter, no http — so the domain layer may use it.
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Someone else is on this slot right now. Temporary: it frees up when they
/// leave or their hold runs out ([retryAfter] seconds at most).
final class SlotHeldFailure extends Failure {
  const SlotHeldFailure(super.message, {this.retryAfter});

  final int? retryAfter;
}

/// The slot is booked. It stays taken until that order is cancelled.
final class SlotBookedFailure extends Failure {
  const SlotBookedFailure(super.message);
}

/// The server rejected the input; [message] has every problem, one per line.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, List<String>> fieldErrors;
}

/// Not logged in, or the session is no longer valid.
final class UnauthenticatedFailure extends Failure {
  const UnauthenticatedFailure([super.message = 'Please log in again.']);
}

/// The request never got a proper answer: offline, server down, timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Could not reach the server. Please try again.']);
}

/// Anything else the server said no to (not found, forbidden, 5xx…).
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}
