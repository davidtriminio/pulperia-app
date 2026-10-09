import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/account/account_validation.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import 'auth_widgets.dart';

/// Inicio de sesión (RF-3). El primer inicio en un teléfono requiere conexión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onGoToRegister});

  final VoidCallback onGoToRegister;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  AccountError? _emailError;
  AccountError? _passwordError;
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final emailError = validateEmail(_email.text);
    final passwordError = _password.text.isEmpty
        ? AccountError.passwordRequired
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _error = null;
    });
    if (emailError != null || passwordError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(_email.text, _password.text);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    }
    // Con éxito la puerta de acceso cambia de pantalla y esta se destruye.
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    key: const ValueKey('login-screen'),
    title: Strings.signInTitle,
    subtitle: Strings.signInSubtitle,
    children: [
      TextField(
        key: const ValueKey('auth-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(254)],
        decoration: InputDecoration(
          labelText: Strings.fieldEmail,
          error: fieldError(
            _emailError == null ? null : accountErrorText(_emailError!),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('auth-password'),
        controller: _password,
        obscureText: !_showPassword,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        inputFormatters: [LengthLimitingTextInputFormatter(maxPasswordLength)],
        decoration: InputDecoration(
          labelText: Strings.fieldPassword,
          error: fieldError(
            _passwordError == null ? null : accountErrorText(_passwordError!),
          ),
          suffixIcon: IconButton(
            key: const ValueKey('auth-password-toggle'),
            tooltip: _showPassword
                ? Strings.hidePassword
                : Strings.showPassword,
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (_error != null) ...[
        KeyedSubtree(
          key: const ValueKey('auth-error'),
          child: ErrorBanner(_error!),
        ),
        const SizedBox(height: 12),
      ],
      KeyedSubtree(
        key: const ValueKey('auth-submit'),
        child: BusyButton(
          label: Strings.signInAction,
          busy: _busy,
          onPressed: _submit,
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const ValueKey('auth-go-register'),
        onPressed: _busy ? null : widget.onGoToRegister,
        child: const Text(Strings.goToRegister),
      ),
    ],
  );
}
