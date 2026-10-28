import '../../../../core/network/api_client.dart';

/// The slot, hold and order endpoints. Returns raw JSON; the repository maps it.
///
/// The Idempotency-Key header is an HTTP detail, so it is handled here and
/// never leaks upward: each [book] call is one attempt and gets its own fresh
/// key from [_newIdempotencyKey]. (Reusing a key across edits would make the
/// server replay an old answer instead of looking at the corrected request.)
class BookingRemoteDataSource {
  BookingRemoteDataSource(this._client, this._newIdempotencyKey);

  final ApiClient _client;
  final String Function() _newIdempotencyKey;

  Future<List<Map<String, dynamic>>> slots(int workstationId, {required String date}) async {
    final data = await _client.get('/workstations/$workstationId/slots', query: {'date': date}) as Map<String, dynamic>;
    return _rows(data);
  }

  Future<Map<String, dynamic>> hold(int slotId) async {
    final data = await _client.post('/workstation-slots/$slotId/hold') as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<void> release(int slotId) async {
    await _client.delete('/workstation-slots/$slotId/hold');
  }

  Future<Map<String, dynamic>> book({
    required int slotId,
    required String customerName,
    String? notes,
  }) async {
    final data = await _client.post(
      '/orders',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'customer_name': customerName,
        'workstation_slot_id': slotId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    ) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> orders({String? status, int? workstationId}) async {
    final data = await _client.get(
      '/orders',
      query: {
        if (status != null) 'status': status,
        if (workstationId != null) 'workstation_id': workstationId,
      },
    ) as Map<String, dynamic>;
    return _rows(data);
  }

  Future<List<Map<String, dynamic>>> ordersForWorkstation(int workstationId) async {
    final data = await _client.get('/workstations/$workstationId/orders') as Map<String, dynamic>;
    return _rows(data);
  }

  Future<Map<String, dynamic>> order(int id) async {
    final data = await _client.get('/orders/$id') as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStatus(int id, String status) async {
    final data = await _client.patch('/orders/$id/status', body: {'status': status}) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<void> deleteOrder(int id) async {
    await _client.delete('/orders/$id');
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> body) {
    return (body['data'] as List).cast<Map<String, dynamic>>();
  }
}
