import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../../l10n/strings.dart';
import '../home_shell.dart';

/// Decide qué ve el usuario según su sesión (RF-3, RF-6): las pantallas de
/// trabajo solo con sesión iniciada y un negocio elegido.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return session.when(
      loading: () => const Scaffold(
        body: Center(
          key: ValueKey('auth-loading'),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const _SignInPending(),
      data: (state) => switch (state) {
        SignedIn(active: != null) => const HomeShell(),
        _ => const _SignInPending(),
      },
    );
  }
}

/// Provisional hasta las pantallas de registro e inicio de sesión (T105).
class _SignInPending extends StatelessWidget {
  const _SignInPending();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      key: ValueKey('auth-pending'),
      child: Text(Strings.signInRequired),
    ),
  );
}
