import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<bool> hasStoredSession() => _remote.hasStoredSession();

  @override
  Future<AppUser> register({required String name, required String email, required String password}) {
    return guardFailures(() async {
      return UserMapper.fromJson(await _remote.register(name: name, email: email, password: password));
    });
  }

  @override
  Future<AppUser> login({required String email, required String password}) {
    return guardFailures(() async {
      return UserMapper.fromJson(await _remote.login(email: email, password: password));
    });
  }

  @override
  Future<AppUser> currentUser() {
    return guardFailures(() async => UserMapper.fromJson(await _remote.currentUser()));
  }

  @override
  Future<void> logout() => guardFailures(_remote.logout);

  @override
  Future<void> clearSession() => _remote.clearSession();

  @override
  Stream<void> get sessionExpired => _remote.sessionExpired;
}
