import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../data/datasources/booking_remote_data_source.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/repositories/booking_repository.dart';

/// Wires the booking feature's layers together. Every ViewModel asks for a
/// [BookingRepository]; only here does anyone say it is the HTTP-backed one.
/// A test overrides this provider with a fake and exercises the ViewModels
/// with no network, no clock and no waiting.
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepositoryImpl(
    BookingRemoteDataSource(ref.watch(apiClientProvider), ref.watch(idGeneratorProvider)),
    now: ref.watch(nowProvider),
  ),
);
