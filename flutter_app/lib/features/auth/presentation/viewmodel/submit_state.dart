/// State of a form that is submitted once: idle, in flight, or failed.
class SubmitState {
  const SubmitState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;
}
