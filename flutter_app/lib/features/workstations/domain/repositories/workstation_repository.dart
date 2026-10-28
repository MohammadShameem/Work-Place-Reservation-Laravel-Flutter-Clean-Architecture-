import '../entities/workstation.dart';

/// Every method fails with a `Failure` (see core/error/failure.dart).
abstract interface class WorkstationRepository {
  Future<List<Workstation>> list();

  Future<Workstation> create({required String name, required String code, required String location});

  Future<Workstation> setActive(int id, {required bool isActive});
}
