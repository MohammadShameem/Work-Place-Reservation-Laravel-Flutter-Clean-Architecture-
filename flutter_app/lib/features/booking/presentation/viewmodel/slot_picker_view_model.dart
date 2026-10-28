import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/slot_hold.dart';
import '../../domain/entities/workstation_slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../providers/booking_providers.dart';

/// What kind of notice to show, so the View can pick an icon. The ViewModel
/// decides WHAT is said; the View decides how it looks.
enum SlotMessageKind { held, booked, offline }

/// One-off things the ViewModel asks the View to do (it can't touch the
/// screen itself). The View handles it, then calls [SlotPickerViewModel.consumeEvent].
sealed class SlotPickerEvent {
  const SlotPickerEvent();
}

final class ShowSlotMessage extends SlotPickerEvent {
  const ShowSlotMessage(this.text, this.kind);

  final String text;
  final SlotMessageKind kind;
}

/// "The slot is held for you — open the confirm screen."
final class OpenConfirm extends SlotPickerEvent {
  const OpenConfirm(this.slot, this.hold);

  final WorkstationSlot slot;
  final SlotHold hold;
}

class SlotPickerState {
  const SlotPickerState({
    required this.selectedDay,
    this.slots,
    this.error,
    this.isLoading = true,
    this.refreshFailing = false,
    this.isHolding = false,
    this.event,
  });

  final DateTime selectedDay;

  /// Null until the first load for [selectedDay] succeeds.
  final List<WorkstationSlot>? slots;

  /// Why the first load failed. A later background refresh failing does not
  /// set this (the older slots stay on screen); it sets [refreshFailing].
  final Failure? error;
  final bool isLoading;
  final bool refreshFailing;

  /// A tap is waiting for the server to say whether the hold worked.
  final bool isHolding;
  final SlotPickerEvent? event;

  static const _keep = Object();

  SlotPickerState copyWith({
    DateTime? selectedDay,
    Object? slots = _keep,
    Object? error = _keep,
    bool? isLoading,
    bool? refreshFailing,
    bool? isHolding,
    Object? event = _keep,
  }) {
    return SlotPickerState(
      selectedDay: selectedDay ?? this.selectedDay,
      slots: identical(slots, _keep) ? this.slots : slots as List<WorkstationSlot>?,
      error: identical(error, _keep) ? this.error : error as Failure?,
      isLoading: isLoading ?? this.isLoading,
      refreshFailing: refreshFailing ?? this.refreshFailing,
      isHolding: isHolding ?? this.isHolding,
      event: identical(event, _keep) ? this.event : event as SlotPickerEvent?,
    );
  }
}

/// The slot picker's brain: loads a day's slots, keeps them fresh by polling,
/// and turns a tap into "hold it, then open the confirm screen".
///
/// The list refreshes itself every few seconds, so when another user starts
/// booking a slot it turns "being selected" here within moments (and free
/// again if they back out). Tapping a free slot first HOLDS it, so the person
/// who is too late finds out right here, before typing anything.
class SlotPickerViewModel extends Notifier<SlotPickerState> {
  SlotPickerViewModel(this.workstationId);

  final int workstationId;

  static const pollInterval = Duration(seconds: 5);

  Timer? _pollTimer;
  int _requestCounter = 0; // lets a stale response (an old day) be ignored
  bool _confirmOpen = false;
  bool _inForeground = true;

  BookingRepository get _repository => ref.read(bookingRepositoryProvider);

  @override
  SlotPickerState build() {
    ref.onDispose(() => _pollTimer?.cancel());

    Future.microtask(() {
      if (!ref.mounted) return;
      _fetch(initial: true);
      _schedulePoll();
    });

    return SlotPickerState(selectedDay: ref.read(nowProvider)());
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day, slots: null, error: null, isLoading: true);
    _fetch(initial: true);
  }

  /// The View tells us when the app goes to the background or comes back.
  /// No point asking the server while nobody is looking.
  void setForeground(bool inForeground) {
    _inForeground = inForeground;
    if (inForeground) _fetch(); // catch up now instead of waiting for the next tick
  }

  Future<void> retry() => _fetch(initial: true);

  Future<void> onSlotTap(WorkstationSlot slot) async {
    if (state.isHolding) return;

    // Someone else is on it. We already know that from the list, so no
    // round trip is needed to explain it.
    if (slot.isHeldByAnother) {
      _emit(ShowSlotMessage(_heldMessage(slot), SlotMessageKind.held));
      return;
    }
    if (!slot.canSelect) return;

    state = state.copyWith(isHolding: true);
    try {
      // The list may be a few seconds old, so the server has the final say.
      final hold = await _repository.holdSlot(slot.id);
      if (!ref.mounted) return;

      _confirmOpen = true; // the confirm screen keeps the hold alive itself
      _emit(OpenConfirm(slot, hold));
    } on SlotHeldFailure catch (failure) {
      _emit(ShowSlotMessage(failure.message, SlotMessageKind.held));
      _fetch(); // the picture on screen was out of date; fix it now
    } on SlotBookedFailure catch (failure) {
      _emit(ShowSlotMessage(failure.message, SlotMessageKind.booked));
      _fetch();
    } on Failure catch (failure) {
      _emit(ShowSlotMessage(failure.message, SlotMessageKind.offline));
    } finally {
      if (ref.mounted) state = state.copyWith(isHolding: false);
    }
  }

  /// The View calls this when the confirm screen closes.
  void confirmClosed({required bool booked}) {
    _confirmOpen = false;
    if (!booked) _fetch(); // the slot may have changed while we were away
  }

  void consumeEvent() {
    if (ref.mounted) state = state.copyWith(event: null);
  }

  void _emit(SlotPickerEvent event) {
    if (ref.mounted) state = state.copyWith(event: event);
  }

  /// A one-shot timer that re-arms itself after each fetch, so a slow
  /// response can never pile up overlapping requests. A little random jitter
  /// stops every open screen from hitting the server on the same beat.
  void _schedulePoll() {
    _pollTimer?.cancel();
    final jitter = Duration(milliseconds: ref.read(randomProvider).nextInt(1000));

    _pollTimer = Timer(pollInterval + jitter, () async {
      if (!ref.mounted) return;
      if (!_confirmOpen && _inForeground) await _fetch();
      if (ref.mounted) _schedulePoll();
    });
  }

  Future<void> _fetch({bool initial = false}) async {
    final requestId = ++_requestCounter;
    final day = state.selectedDay;

    try {
      final slots = await _repository.slots(workstationId, day);
      if (!ref.mounted || requestId != _requestCounter) return;
      state = state.copyWith(slots: slots, error: null, isLoading: false, refreshFailing: false);
    } on Failure catch (failure) {
      if (!ref.mounted || requestId != _requestCounter) return;

      // Keep showing what we already have; only a first load is an error screen.
      if (initial || state.slots == null) {
        state = state.copyWith(isLoading: false, error: failure);
      } else {
        state = state.copyWith(isLoading: false, refreshFailing: true);
      }
    }
  }

  String _heldMessage(WorkstationSlot slot) {
    final until = slot.heldUntil;
    final minutes = until == null
        ? null
        : max(1, (until.difference(ref.read(nowProvider)().toUtc()).inSeconds / 60).ceil());
    final when = minutes == null ? '' : ' It may free up within about $minutes min.';

    return 'Another user is selecting this slot right now. It is not available at the moment, '
        'but it may become available again shortly.$when';
  }
}

/// One per workstation being looked at; gone (and its polling stopped) when
/// the screen closes.
final slotPickerViewModelProvider = NotifierProvider.autoDispose
    .family<SlotPickerViewModel, SlotPickerState, int>(SlotPickerViewModel.new);
