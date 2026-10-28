import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../data/datasources/workstation_remote_data_source.dart';
import '../../data/repositories/workstation_repository_impl.dart';
import '../../domain/repositories/workstation_repository.dart';

/// Wires the workstations feature's layers together; a test overrides this
/// with a fake [WorkstationRepository].
final workstationRepositoryProvider = Provider<WorkstationRepository>(
  (ref) => WorkstationRepositoryImpl(WorkstationRemoteDataSource(ref.watch(apiClientProvider))),
);
