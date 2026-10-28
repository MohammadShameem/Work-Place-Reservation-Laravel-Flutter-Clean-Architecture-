import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../providers/auth_providers.dart';
import 'auth_view_model.dart';
import 'submit_state.dart';

class LoginViewModel extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit({required String email, required String password}) async {
    state = const SubmitState(isSubmitting: true);

    try {
      final user = await ref.read(authRepositoryProvider).login(email: email, password: password);
      // The root widget now swaps to the main app and this screen goes away.
      ref.read(authViewModelProvider.notifier).signedIn(user);
    } on Failure catch (failure) {
      if (ref.mounted) state = SubmitState(errorMessage: failure.message);
    }
  }
}

final loginViewModelProvider = NotifierProvider.autoDispose<LoginViewModel, SubmitState>(LoginViewModel.new);
