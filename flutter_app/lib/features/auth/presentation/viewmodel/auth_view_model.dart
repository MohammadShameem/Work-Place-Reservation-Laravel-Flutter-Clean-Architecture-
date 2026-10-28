import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final AppUser? user;
}

/// Who is logged in. The single source of truth for "is anyone logged in
/// right now" — the app's root widget switches between the login flow and the
/// main app by watching this.
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.read(authRepositoryProvider);

    // Both tokens rejected mid-use -> back to login.
    final subscription = repository.sessionExpired.listen((_) => _handleSessionExpired());
    ref.onDispose(subscription.cancel);

    Future.microtask(_bootstrap);
    return const AuthState(status: AuthStatus.checking);
  }

  /// On launch: if a login is saved, confirm it still works by asking for
  /// the current user instead of trusting stale local state.
  Future<void> _bootstrap() async {
    final repository = ref.read(authRepositoryProvider);

    if (!await repository.hasStoredSession()) {
      if (ref.mounted) state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await repository.currentUser();
      if (ref.mounted) state = AuthState(status: AuthStatus.authenticated, user: user);
    } on Failure {
      await repository.clearSession();
      if (ref.mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Called by the login / register ViewModels once the server said yes.
  void signedIn(AppUser user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);

    try {
      await repository.logout();
    } on Failure {
      // The token may already be gone or expired on the server; the local
      // login is cleared below regardless, which is what the user asked for.
    }
    await repository.clearSession();
    if (ref.mounted) state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void _handleSessionExpired() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
