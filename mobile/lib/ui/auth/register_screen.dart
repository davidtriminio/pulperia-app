import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/account/account_validation.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../input_limits.dart';
import 'auth_widgets.dart';

/// Crear la cuenta con el primer negocio (RF-1, RF-7, RF-78). Requiere conexión.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.onGoToLogin});

  final VoidCallback onGoToLogin;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _business = TextEditingController();
  AmountMode? _amount;
  QuantityMode? _quantity;
  AccountError? _emailError;
  AccountError? _passwordError;
  AccountError? _businessError;
  bool _amountMissing = false;
  bool _quantityMissing = false;
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _business.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final emailError = validateEmail(_email.text);
    final passwordError = validatePassword(_password.text);
    final businessError = validateBusinessName(_business.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _businessError = businessError;
      _amountMissing = _amount == null;
      _quantityMissing = _quantity == null;
      _error = null;
    });
    final amount = _amount;
    final quantity = _quantity;
    if (emailError != null ||
        passwordError != null ||
        businessError != null ||
        amount == null ||
        quantity == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            email: _email.text,
            password: _password.text,
            businessName: _business.text,
            amountMode: amount,
            quantityMode: quantity,
          );
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
    key: const ValueKey('register-screen'),
    title: Strings.createAccountTitle,
    subtitle: Strings.createAccountSubtitle,
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
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(maxPasswordLength)],
        decoration: InputDecoration(
          labelText: Strings.fieldPassword,
          helperText: Strings.passwordHint,
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
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('register-business-name'),
        controller: _business,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(InputLimits.name)],
        decoration: InputDecoration(
          labelText: Strings.fieldBusinessName,
          error: fieldError(
            _businessError == null ? null : accountErrorText(_businessError!),
          ),
        ),
      ),
      const SizedBox(height: 20),
      ModeChoices(
        amount: _amount,
        quantity: _quantity,
        amountError: _amountMissing && _amount == null
            ? Strings.amountModeRequired
            : null,
        quantityError: _quantityMissing && _quantity == null
            ? Strings.quantityModeRequired
            : null,
        onAmount: (mode) => setState(() => _amount = mode),
        onQuantity: (mode) => setState(() => _quantity = mode),
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
          label: Strings.createAccountAction,
          busy: _busy,
          onPressed: _submit,
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const ValueKey('auth-go-login'),
        onPressed: _busy ? null : widget.onGoToLogin,
        child: const Text(Strings.goToLogin),
      ),
    ],
  );
}
