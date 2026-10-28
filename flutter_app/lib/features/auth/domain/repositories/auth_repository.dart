import '../entities/app_user.dart';

/// What the app needs from "the login system" — nothing about how it is done.
/// Every method fails with a `Failure` (see core/error/failure.dart).
abstract interface class AuthRepository {
  /// Is there a saved login on this device? (Says nothing about whether it
  /// is still valid — [currentUser] finds that out.)
  Future<bool> hasStoredSession();

  Future<AppUser> register({required String name, required String email, required String password});

  Future<AppUser> login({required String email, required String password});

  /// The user the saved login belongs to. Fails if it is no longer valid.
  Future<AppUser> currentUser();

  /// Ends the session on the server.
  Future<void> logout();

  /// Forgets the saved login on this device, without asking the server.
  Future<void> clearSession();

  /// Fires when the saved login stops working mid-use (both tokens are
  /// rejected), so the app can send the user back to the login screen.
  Stream<void> get sessionExpired;
}
