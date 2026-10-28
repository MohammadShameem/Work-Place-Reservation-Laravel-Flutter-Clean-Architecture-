import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../providers/auth_providers.dart';
import 'auth_view_model.dart';
import 'submit_state.dart';

class RegisterViewModel extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit({required String name, required String email, required String password}) async {
    state = const SubmitState(isSubmitting: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
      ref.read(authViewModelProvider.notifier).signedIn(user);
    } on Failure catch (failure) {
      if (ref.mounted) state = SubmitState(errorMessage: failure.message);
    }
  }
}

final registerViewModelProvider =
    NotifierProvider.autoDispose<RegisterViewModel, SubmitState>(RegisterViewModel.new);
