import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(
    ProviderScope(
      // Riverpod 3 re-runs a provider that throws, a few times, on its own.
      // Nothing here should be retried behind the user's back (a failed
      // booking must be the user's decision), so turn that off.
      retry: (retryCount, error) => null,
      child: const OrderApp(),
    ),
  );
}
