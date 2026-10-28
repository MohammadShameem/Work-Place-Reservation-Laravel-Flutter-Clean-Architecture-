import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/workstation.dart';
import '../providers/workstation_providers.dart';

class WorkstationsState {
  const WorkstationsState({
    this.isLoading = true,
    this.error,
    this.items = const [],
    this.notice,
  });

  final bool isLoading;

  /// Why the list could not be loaded (shown instead of the list when empty).
  final String? error;
  final List<Workstation> items;

  /// A one-off message for the View to show once (a snackbar), then clear.
  final String? notice;

  static const _keep = Object();

  WorkstationsState copyWith({
    bool? isLoading,
    Object? error = _keep,
    List<Workstation>? items,
    Object? notice = _keep,
  }) {
    return WorkstationsState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _keep) ? this.error : error as String?,
      items: items ?? this.items,
      notice: identical(notice, _keep) ? this.notice : notice as String?,
    );
  }
}

class WorkstationsViewModel extends Notifier<WorkstationsState> {
  @override
  WorkstationsState build() {
    Future.microtask(load);
    return const WorkstationsState();
  }

  Future<void> load() async {
    if (!ref.mounted) return; // a stale callback after the screen went away
    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = await ref.read(workstationRepositoryProvider).list();
      if (ref.mounted) state = state.copyWith(isLoading: false, items: items);
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  /// Returns null on success, or the reason it failed (for the dialog to show).
  Future<String?> create({required String name, required String code, required String location}) async {
    try {
      final created = await ref
          .read(workstationRepositoryProvider)
          .create(name: name, code: code, location: location);

      if (ref.mounted) {
        final items = [...state.items, created]..sort((a, b) => a.code.compareTo(b.code));
        state = state.copyWith(items: items);
      }
      return null;
    } on Failure catch (failure) {
      return failure.message;
    }
  }

  Future<void> setActive(Workstation workstation, bool isActive) async {
    try {
      final updated = await ref
          .read(workstationRepositoryProvider)
          .setActive(workstation.id, isActive: isActive);

      if (!ref.mounted) return;
      state = state.copyWith(
        items: [for (final w in state.items) w.id == updated.id ? updated : w],
      );
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(notice: failure.message);
    }
  }

  void consumeNotice() => state = state.copyWith(notice: null);
}

final workstationsViewModelProvider =
    NotifierProvider.autoDispose<WorkstationsViewModel, WorkstationsState>(WorkstationsViewModel.new);
