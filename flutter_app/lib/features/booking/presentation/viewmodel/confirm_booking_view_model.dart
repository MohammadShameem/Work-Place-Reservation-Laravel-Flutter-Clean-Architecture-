import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/slot_hold.dart';
import '../providers/booking_providers.dart';
import 'orders_view_model.dart';

/// What the confirm screen needs to start: which slot, and the hold the
/// slot picker just got for it. Two args are equal if they describe the same
/// hold, so rebuilding the screen doesn't create a second ViewModel.
class ConfirmBookingArgs {
  const ConfirmBookingArgs({required this.slotId, required this.hold});

  final int slotId;
  final SlotHold hold;

  @override
  bool operator ==(Object other) =>
      other is ConfirmBookingArgs && other.slotId == slotId && other.hold.expiresAt == hold.expiresAt;

  @override
  int get hashCode => Object.hash(slotId, hold.expiresAt);
}

sealed class ConfirmBookingEvent {
  const ConfirmBookingEvent();
}

/// The countdown reached zero: ask whether to try to hold the slot again.
final class HoldExpired extends ConfirmBookingEvent {
  const HoldExpired();
}

/// Close the screen. [booked] tells the slot picker whether to close too.
final class Finished extends ConfirmBookingEvent {
  const Finished({required this.booked});

  final bool booked;
}

class ConfirmBookingState {
  const ConfirmBookingState({
    required this.hold,
    required this.remaining,
    this.isSubmitting = false,
    this.slotLost = false,
    this.errorMessage,
    this.event,
  });

  final SlotHold hold;
  final Duration remaining;
  final bool isSubmitting;

  /// Someone else has the slot now. Nothing more can be done here but leave.
  final bool slotLost;
  final String? errorMessage;
  final ConfirmBookingEvent? event;

  static const _warnBelow = Duration(seconds: 30);

  bool get isRunningOut => !slotLost && remaining <= _warnBelow;

  static const _keep = Object();

  ConfirmBookingState copyWith({
    SlotHold? hold,
    Duration? remaining,
    bool? isSubmitting,
    bool? slotLost,
    Object? errorMessage = _keep,
    Object? event = _keep,
  }) {
    return ConfirmBookingState(
      hold: hold ?? this.hold,
      remaining: remaining ?? this.remaining,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      slotLost: slotLost ?? this.slotLost,
      errorMessage: identical(errorMessage, _keep) ? this.errorMessage : errorMessage as String?,
      event: identical(event, _keep) ? this.event : event as ConfirmBookingEvent?,
    );
  }
}

/// The confirm screen's brain: counts the hold down, books on confirm, and
/// gives the slot back if the user walks away.
class ConfirmBookingViewModel extends Notifier<ConfirmBookingState> {
  ConfirmBookingViewModel(this.args);

  final ConfirmBookingArgs args;

  Timer? _ticker;
  bool _isBooked = false;
  bool _expiryReported = false;

  DateTime _now() => ref.read(nowProvider)();

  @override
  ConfirmBookingState build() {
    // Taken now: a ref can't be used from inside onDispose.
    final repository = ref.read(bookingRepositoryProvider);

    ref.onDispose(() {
      _ticker?.cancel();

      // Leaving without booking (back button, app navigation): give the slot
      // back right away instead of making others wait out the timer. Best
      // effort — if it fails, or the tab is simply closed, the hold lapses by
      // itself. Calling it when we no longer own the hold is harmless.
      if (!_isBooked) {
        unawaited(repository.releaseSlot(args.slotId).catchError((Object _) {}));
      }
    });

    _startTicker();
    return ConfirmBookingState(hold: args.hold, remaining: args.hold.remaining(_now()));
  }

  Future<void> submit({required String customerName, String? notes}) async {
    if (state.slotLost) {
      leave();
      return;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      await ref.read(bookingRepositoryProvider).bookSlot(
        slotId: args.slotId,
        customerName: customerName,
        notes: notes,
      );

      _isBooked = true; // the order owns the slot now; nothing to release
      _ticker?.cancel();
      ref.invalidate(ordersViewModelProvider); // the orders list is out of date
      if (ref.mounted) state = state.copyWith(isSubmitting: false, event: const Finished(booked: true));
    } on SlotHeldFailure catch (failure) {
      _giveUp(failure.message);
    } on SlotBookedFailure catch (failure) {
      _giveUp(failure.message);
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isSubmitting: false, errorMessage: failure.message);
    }
  }

  /// "Try again" after the hold ran out. Only works if nobody else took the slot meanwhile.
  Future<void> retryHold() async {
    _expiryReported = false;

    try {
      final hold = await ref.read(bookingRepositoryProvider).holdSlot(args.slotId);
      if (!ref.mounted) return;

      state = state.copyWith(hold: hold, remaining: hold.remaining(_now()), errorMessage: null);
      _startTicker();
    } on Failure catch (failure) {
      _giveUp(failure.message);
    }
  }

  void leave() {
    if (ref.mounted) state = state.copyWith(event: const Finished(booked: false));
  }

  void consumeEvent() {
    if (ref.mounted) state = state.copyWith(event: null);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ref.mounted) return;

      final remaining = state.hold.remaining(_now());
      state = state.copyWith(remaining: remaining);
      if (remaining <= Duration.zero) _onExpired();
    });
  }

  void _onExpired() {
    _ticker?.cancel();
    if (_expiryReported || _isBooked || state.slotLost) return;

    _expiryReported = true;
    state = state.copyWith(event: const HoldExpired());
  }

  /// The slot is not ours any more. Stop the countdown and explain; the only
  /// useful action left is going back to pick another slot.
  void _giveUp(String message) {
    _ticker?.cancel();
    if (ref.mounted) state = state.copyWith(isSubmitting: false, slotLost: true, errorMessage: message);
  }
}

final confirmBookingViewModelProvider = NotifierProvider.autoDispose
    .family<ConfirmBookingViewModel, ConfirmBookingState, ConfirmBookingArgs>(ConfirmBookingViewModel.new);
