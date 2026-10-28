import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:order_app/core/error/failure.dart';
import 'package:order_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:order_app/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:order_app/features/auth/presentation/viewmodel/login_view_model.dart';

import '../../../support/fakes.dart';

ProviderContainer containerWith(FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the ViewModel's start-up check (a few awaited calls) finish.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  group('on launch', () {
    test('nobody saved: goes straight to the login screen without asking the server', () async {
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});

      expect(container.read(authViewModelProvider).status, AuthStatus.checking);
      await settle();

      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
      expect(repo.currentUserCalls, 0);
    });

    test('a saved login that still works signs the user straight in', () async {
      repo.hasSession = true;
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      await settle();

      final state = container.read(authViewModelProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user!.name, 'Momin');
    });

    test('a saved login that no longer works is forgotten', () async {
      repo
        ..hasSession = true
        ..currentUserFailure = const UnauthenticatedFailure();
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      await settle();

      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
      expect(repo.clearCalls, 1);
    });
  });

  group('while using the app', () {
    test('both tokens being rejected sends the user back to login', () async {
      repo.hasSession = true;
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      await settle();
      expect(container.read(authViewModelProvider).status, AuthStatus.authenticated);

      repo.expireSession();
      await settle();

      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
    });

    test('logging out clears the saved login', () async {
      repo.hasSession = true;
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      await settle();

      await container.read(authViewModelProvider.notifier).logout();

      expect(repo.logoutCalls, 1);
      expect(repo.clearCalls, 1);
      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
    });

    test('logging out works even if the server cannot be reached', () async {
      repo
        ..hasSession = true
        ..logoutFailure = const NetworkFailure();
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      await settle();

      await container.read(authViewModelProvider.notifier).logout();

      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
      expect(repo.clearCalls, 1, reason: 'the user asked to be logged out; do it locally regardless');
    });
  });

  group('login form', () {
    test('success signs the user in', () async {
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      container.listen(loginViewModelProvider, (_, _) {});
      await settle();

      await container.read(loginViewModelProvider.notifier).submit(email: 'a@b.c', password: 'password123');

      expect(container.read(authViewModelProvider).status, AuthStatus.authenticated);
    });

    test('a wrong password shows the server\'s message and signs nobody in', () async {
      repo.loginFailure = const ValidationFailure('The provided credentials are incorrect.');
      final container = containerWith(repo);
      container.listen(authViewModelProvider, (_, _) {});
      container.listen(loginViewModelProvider, (_, _) {});
      await settle();

      await container.read(loginViewModelProvider.notifier).submit(email: 'a@b.c', password: 'wrong');

      final form = container.read(loginViewModelProvider);
      expect(form.errorMessage, 'The provided credentials are incorrect.');
      expect(form.isSubmitting, isFalse);
      expect(container.read(authViewModelProvider).status, AuthStatus.unauthenticated);
    });
  });
}
