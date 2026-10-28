import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

/// Where the auth feature's layers are wired together. Everything above this
/// file asks for an [AuthRepository]; only here does anyone say it is the
/// HTTP-backed one. A test overrides this provider with a fake.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remote = AuthRemoteDataSource(
    client: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    deviceName: ref.watch(deviceNameProvider),
  );
  ref.onDispose(remote.dispose);
  return AuthRepositoryImpl(remote);
});
