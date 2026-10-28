import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:order_app/core/error/failure.dart';
import 'package:order_app/core/network/api_exception.dart';
import 'package:order_app/core/network/failure_mapper.dart';

void main() {
  group('failureFromApiException', () {
    test('a slot held by someone else keeps its retry hint', () {
      final failure = failureFromApiException(
        ApiException.fromResponseBody(409, {'message': 'Busy.', 'code': 'slot_held', 'retry_after': 142}),
      );

      expect(failure, isA<SlotHeldFailure>());
      expect((failure as SlotHeldFailure).retryAfter, 142);
      expect(failure.message, 'Busy.');
    });

    test('a booked slot', () {
      final failure = failureFromApiException(
        ApiException.fromResponseBody(409, {'message': 'Booked.', 'code': 'slot_booked'}),
      );

      expect(failure, isA<SlotBookedFailure>());
    });

    test('a 422 becomes a validation failure with every problem on its own line', () {
      final failure = failureFromApiException(
        ApiException.fromResponseBody(422, {
          'message': 'Invalid.',
          'errors': {
            'email': ['The email field is required.'],
            'password': ['Too short.', 'Needs a number.'],
          },
        }),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'The email field is required.\nToo short.\nNeeds a number.');
      expect((failure as ValidationFailure).fieldErrors['password'], hasLength(2));
    });

    test('a 401 means not logged in', () {
      expect(
        failureFromApiException(ApiException.fromResponseBody(401, {'message': 'Unauthenticated.'})),
        isA<UnauthenticatedFailure>(),
      );
    });

    test('anything else is a server failure that remembers the status', () {
      final failure = failureFromApiException(ApiException.fromResponseBody(404, {'message': 'Not found.'}));

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 404);
    });

    test('a plain 409 with no slot code is not mistaken for a slot conflict', () {
      final failure = failureFromApiException(ApiException.fromResponseBody(409, {'message': 'Still processing.'}));

      expect(failure, isA<ServerFailure>());
    });
  });

  group('guardFailures', () {
    test('passes the result through', () async {
      expect(await guardFailures(() async => 42), 42);
    });

    test('translates an API error', () async {
      await expectLater(
        guardFailures<void>(() async => throw ApiException.fromResponseBody(409, {'code': 'slot_booked'})),
        throwsA(isA<SlotBookedFailure>()),
      );
    });

    test('leaves a Failure that is already one alone', () async {
      const original = SlotHeldFailure('x', retryAfter: 5);

      await expectLater(guardFailures<void>(() async => throw original), throwsA(same(original)));
    });

    test('a dropped connection becomes a network failure', () async {
      await expectLater(
        guardFailures<void>(() async => throw http.ClientException('connection reset')),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        guardFailures<void>(() async => throw TimeoutException('too slow')),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a programming error is NOT disguised as a network problem', () async {
      await expectLater(
        guardFailures<void>(() async => throw StateError('a real bug')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
