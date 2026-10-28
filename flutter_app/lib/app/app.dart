import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/loading_view.dart';
import '../features/auth/presentation/view/login_page.dart';
import '../features/auth/presentation/viewmodel/auth_view_model.dart';
import 'home_shell.dart';

class OrderApp extends StatelessWidget {
  const OrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workstation Orders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
      ),
      home: const AuthGate(),
    );
  }
}

/// Switches between the login flow and the main app based on the auth
/// ViewModel's status — the single source of truth for "is anyone logged in".
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authViewModelProvider.select((s) => s.status));

    return switch (status) {
      AuthStatus.checking => const Scaffold(body: LoadingView()),
      AuthStatus.unauthenticated => const LoginPage(),
      AuthStatus.authenticated => const HomeShell(),
    };
  }
}
