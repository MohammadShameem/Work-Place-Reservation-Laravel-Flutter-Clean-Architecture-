import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../network/api_client.dart';
import '../network/token_storage.dart';

/// Dependency injection, Flutter side.
///
/// Riverpod providers are the container: every class gets what it needs
/// through its constructor, and the only place that says "use THIS concrete
/// thing" is a provider. A test swaps any of them with
/// `ProviderScope(overrides: [...])` and nothing else changes.

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ApiConfig.baseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);

/// "What time is it?" as a dependency, so countdowns and polling can be
/// tested by driving a fake clock instead of waiting.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Jitter for the polling timer. Seedable in tests.
final randomProvider = Provider<Random>((ref) => Random());

/// A fresh unique key per call (used as the Idempotency-Key header).
final idGeneratorProvider = Provider<String Function()>((ref) => () => const Uuid().v4());

/// A label for this install, sent so the server can name the login session.
final deviceNameProvider = Provider<String>((ref) {
  if (kIsWeb) return 'flutter-web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'flutter-android',
    TargetPlatform.iOS => 'flutter-ios',
    TargetPlatform.windows => 'flutter-windows',
    TargetPlatform.macOS => 'flutter-macos',
    TargetPlatform.linux => 'flutter-linux',
    _ => 'flutter-app',
  };
});
