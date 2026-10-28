import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/workstation.dart';
import '../../domain/repositories/workstation_repository.dart';
import '../datasources/workstation_remote_data_source.dart';
import '../models/workstation_mapper.dart';

class WorkstationRepositoryImpl implements WorkstationRepository {
  WorkstationRepositoryImpl(this._remote);

  final WorkstationRemoteDataSource _remote;

  @override
  Future<List<Workstation>> list() {
    return guardFailures(() async => (await _remote.list()).map(WorkstationMapper.fromJson).toList());
  }

  @override
  Future<Workstation> create({required String name, required String code, required String location}) {
    return guardFailures(() async {
      return WorkstationMapper.fromJson(await _remote.create(name: name, code: code, location: location));
    });
  }

  @override
  Future<Workstation> setActive(int id, {required bool isActive}) {
    return guardFailures(() async {
      return WorkstationMapper.fromJson(await _remote.setActive(id, isActive: isActive));
    });
  }
}
