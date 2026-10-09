import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../home_shell.dart';
import 'business_chooser_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Decide qué ve el usuario según su sesión (RF-3, RF-5, RF-6): las pantallas
/// de trabajo solo con sesión iniciada y un negocio elegido.
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
      // Si la sesión guardada no se pudo leer, se empieza de nuevo.
      error: (_, _) => const _SignedOutFlow(),
      data: (state) => switch (state) {
        SignedIn(active: != null) => const HomeShell(),
        SignedIn() => const BusinessChooserScreen(),
        SignedOut() => const _SignedOutFlow(),
      },
    );
  }
}

/// Inicio de sesión y registro, uno u otro (sin rutas: al entrar, la puerta de
/// acceso reemplaza todo).
class _SignedOutFlow extends StatefulWidget {
  const _SignedOutFlow();

  @override
  State<_SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<_SignedOutFlow> {
  bool _registering = false;

  @override
  Widget build(BuildContext context) => _registering
      ? RegisterScreen(onGoToLogin: () => setState(() => _registering = false))
      : LoginScreen(onGoToRegister: () => setState(() => _registering = true));
}
