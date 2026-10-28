import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:order_app/core/error/failure.dart';
import 'package:order_app/core/network/api_client.dart';
import 'package:order_app/core/network/token_storage.dart';
import 'package:order_app/features/booking/data/datasources/booking_remote_data_source.dart';
import 'package:order_app/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:order_app/features/booking/domain/entities/order_status.dart';
import 'package:order_app/features/booking/domain/entities/workstation_slot.dart';

/// The data layer against a pretend server: what goes out on the wire, and
/// how what comes back becomes entities and failures. No real network.

http.Response json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

Map<String, dynamic> orderJson({String status = 'pending'}) => {
  'id': 5,
  'order_number': 'ORD-20261014-ABC123',
  'customer_name': 'Rahim',
  'status': status,
  'notes': null,
  'workstation': {
    'id': 1,
    'name': 'Workstation 1',
    'code': 'WS-01',
    'location': 'Building A - Floor 1',
    'is_active': true,
  },
  'workstation_slot': {
    'id': 3,
    'starts_at': '2026-10-14T09:00:00.000000Z',
    'ends_at': '2026-10-14T10:00:00.000000Z',
    'status': 'booked',
    'held_until': null,
  },
  'created_at': '2026-10-14T07:00:00.000000Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late BookingRepositoryImpl repository;
  var keyCounter = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-1',
      'access_token_expires_at': '2099-01-01T00:00:00+00:00',
      'refresh_token': 'refresh-1',
      'refresh_token_expires_at': '2099-01-01T00:00:00+00:00',
    });

    requests = [];
    respond = (_) => json({'data': []});
    keyCounter = 0;

    final api = ApiClient(
      baseUrl: 'http://test/api',
      tokenStorage: TokenStorage(),
      httpClient: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );

    repository = BookingRepositoryImpl(
      BookingRemoteDataSource(api, () => 'key-${++keyCounter}'),
      now: () => DateTime.utc(2026, 10, 14, 11, 30),
    );
  });

  group('slots', () {
    test('asks for the right day and turns each status into the app\'s own', () async {
      respond = (_) => json({
        'data': [
          {'id': 1, 'starts_at': '2026-10-14T09:00:00.000000Z', 'ends_at': '2026-10-14T10:00:00.000000Z', 'status': 'available', 'held_until': null},
          {'id': 2, 'starts_at': '2026-10-14T10:00:00.000000Z', 'ends_at': '2026-10-14T11:00:00.000000Z', 'status': 'held', 'held_until': '2026-10-14T10:03:00.000000Z'},
          {'id': 3, 'starts_at': '2026-10-14T11:00:00.000000Z', 'ends_at': '2026-10-14T12:00:00.000000Z', 'status': 'held_by_you', 'held_until': '2026-10-14T11:03:00.000000Z'},
          {'id': 4, 'starts_at': '2026-10-14T12:00:00.000000Z', 'ends_at': '2026-10-14T13:00:00.000000Z', 'status': 'booked', 'held_until': null},
          {'id': 5, 'starts_at': '2026-10-14T13:00:00.000000Z', 'ends_at': '2026-10-14T14:00:00.000000Z', 'status': 'some_future_status', 'held_until': null},
        ],
      });

      final slots = await repository.slots(4, DateTime(2026, 10, 14, 23, 59));

      expect(requests.single.url.path, '/api/workstations/4/slots');
      expect(requests.single.url.queryParameters, {'date': '2026-10-14'});
      expect(slots.map((s) => s.status), [
        SlotStatus.available,
        SlotStatus.held,
        SlotStatus.heldByYou,
        SlotStatus.booked,
        SlotStatus.booked, // an unknown status is treated as taken, never offered
      ]);
      expect(slots[1].heldUntil, DateTime.utc(2026, 10, 14, 10, 3));
      expect(slots[0].heldUntil, isNull);
    });

    test('sends the saved access token', () async {
      await repository.slots(1, DateTime(2026, 10, 14));

      expect(requests.single.headers['Authorization'], 'Bearer access-1');
    });
  });

  group('holding a slot', () {
    test('measures how far the phone\'s clock is from the server\'s', () async {
      respond = (_) => json({
        'data': {
          'workstation_slot_id': 7,
          'expires_at': '2026-10-14T09:03:00.000000Z',
          'server_time': '2026-10-14T09:00:00.000000Z',
        },
      });

      final hold = await repository.holdSlot(7);

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/workstation-slots/7/hold');
      // The phone says 11:30 and the server says 09:00: 2h30 apart, which is
      // exactly what lets the countdown ignore the phone's wrong clock.
      expect(hold.remaining(DateTime.utc(2026, 10, 14, 11, 30)), const Duration(minutes: 3));
    });

    test('"held by someone else" becomes a SlotHeldFailure with the retry hint', () async {
      respond = (_) => json({'message': 'Another user is selecting this slot.', 'code': 'slot_held', 'retry_after': 142}, 409);

      await expectLater(
        repository.holdSlot(7),
        throwsA(isA<SlotHeldFailure>().having((f) => f.retryAfter, 'retryAfter', 142)),
      );
    });

    test('"already booked" becomes a SlotBookedFailure', () async {
      respond = (_) => json({'message': 'Booked.', 'code': 'slot_booked'}, 409);

      await expectLater(repository.holdSlot(7), throwsA(isA<SlotBookedFailure>()));
    });

    test('releasing sends DELETE and accepts an empty answer', () async {
      respond = (_) => http.Response('', 204);

      await repository.releaseSlot(7);

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/api/workstation-slots/7/hold');
    });
  });

  group('booking', () {
    test('sends who and which slot, and returns the order', () async {
      respond = (_) => json({'data': orderJson()}, 201);

      final order = await repository.bookSlot(slotId: 3, customerName: 'Rahim', notes: 'Rush');

      expect(jsonDecode(requests.single.body), {'customer_name': 'Rahim', 'workstation_slot_id': 3, 'notes': 'Rush'});
      expect(order.orderNumber, 'ORD-20261014-ABC123');
      expect(order.status, OrderStatus.pending);
      expect(order.workstation!.location, 'Building A - Floor 1');
      expect(order.workstationSlot!.id, 3);
    });

    test('leaves notes out when there are none', () async {
      respond = (_) => json({'data': orderJson()}, 201);

      await repository.bookSlot(slotId: 3, customerName: 'Rahim');

      expect((jsonDecode(requests.single.body) as Map).containsKey('notes'), isFalse);
    });

    test('every attempt carries its own fresh Idempotency-Key', () async {
      respond = (_) => json({'data': orderJson()}, 201);

      await repository.bookSlot(slotId: 3, customerName: 'Rahim');
      await repository.bookSlot(slotId: 3, customerName: 'Rahim');

      expect(requests[0].headers['Idempotency-Key'], 'key-1');
      expect(requests[1].headers['Idempotency-Key'], 'key-2');
    });

    test('losing the slot while confirming is reported as the right failure', () async {
      respond = (_) => json({'message': 'Held.', 'code': 'slot_held', 'retry_after': 30}, 409);

      await expectLater(repository.bookSlot(slotId: 3, customerName: 'Rahim'), throwsA(isA<SlotHeldFailure>()));
    });
  });

  group('orders', () {
    test('filters go out as the API\'s own words', () async {
      await repository.orders(status: OrderStatus.inProgress, workstationId: 2);

      expect(requests.single.url.queryParameters, {'status': 'in_progress', 'workstation_id': '2'});
    });

    test('no filters means no query', () async {
      await repository.orders();

      expect(requests.single.url.queryParameters, isEmpty);
    });

    test('a status change goes out in the API\'s words and comes back as an entity', () async {
      respond = (_) => json({'data': orderJson(status: 'in_progress')});

      final order = await repository.updateStatus(5, OrderStatus.inProgress);

      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.path, '/api/orders/5/status');
      expect(jsonDecode(requests.single.body), {'status': 'in_progress'});
      expect(order.status, OrderStatus.inProgress);
    });

    test('a refused status change carries the server\'s reason', () async {
      respond = (_) => json({
        'message': 'Invalid.',
        'errors': {'status': ['An order that is completed cannot change to cancelled.']},
      }, 422);

      await expectLater(
        repository.updateStatus(5, OrderStatus.cancelled),
        throwsA(isA<ValidationFailure>().having((f) => f.message, 'message', contains('cannot change'))),
      );
    });
  });

  group('when things go wrong', () {
    test('a dropped connection is a NetworkFailure', () async {
      final api = ApiClient(
        baseUrl: 'http://test/api',
        tokenStorage: TokenStorage(),
        httpClient: MockClient((_) async => throw http.ClientException('connection refused')),
      );
      final offline = BookingRepositoryImpl(BookingRemoteDataSource(api, () => 'k'), now: DateTime.now);

      await expectLater(offline.slots(1, DateTime(2026, 10, 14)), throwsA(isA<NetworkFailure>()));
    });

    test('a missing record is a ServerFailure that remembers the status', () async {
      respond = (_) => json({'message': 'No query results.'}, 404);

      await expectLater(
        repository.order(99),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 404)),
      );
    });
  });
}
