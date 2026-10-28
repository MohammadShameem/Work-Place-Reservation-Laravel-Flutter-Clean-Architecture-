import '../../../../core/network/api_client.dart';

/// The /workstations endpoints. Returns raw JSON; the repository maps it.
class WorkstationRemoteDataSource {
  WorkstationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list() async {
    final data = await _client.get('/workstations') as Map<String, dynamic>;
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String code,
    required String location,
  }) async {
    final data = await _client.post(
      '/workstations',
      body: {'name': name, 'code': code, 'location': location},
    ) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setActive(int id, {required bool isActive}) async {
    final data = await _client.patch('/workstations/$id', body: {'is_active': isActive}) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }
}
