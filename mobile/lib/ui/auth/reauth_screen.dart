import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../../app/sync_controller.dart';
import '../../domain/account/account_validation.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import 'auth_widgets.dart';

/// Volver a entrar con la contraseña cuando la sesión caducó sin conexión
/// (D-10). La app siguió usable y la cola se conservó; esto solo hace falta
/// para sincronizar. Con éxito cierra la pantalla y sincroniza.
class ReauthScreen extends ConsumerStatefulWidget {
  const ReauthScreen({super.key});

  @override
  ConsumerState<ReauthScreen> createState() => _ReauthScreenState();
}

class _ReauthScreenState extends ConsumerState<ReauthScreen> {
  final _password = TextEditingController();
  AccountError? _passwordError;
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final passwordError = _password.text.isEmpty
        ? AccountError.passwordRequired
        : null;
    setState(() {
      _passwordError = passwordError;
      _error = null;
    });
    if (passwordError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .reauthenticate(_password.text);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
      return;
    }
    ref.read(syncControllerProvider.notifier).request(SyncTrigger.manual);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final email = session is SignedIn ? session.email : '';
    return AuthPage(
      key: const ValueKey('reauth-screen'),
      title: Strings.reauthTitle,
      subtitle: Strings.reauthSubtitle(email),
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const ValueKey('reauth-close'),
          tooltip: Strings.cancel,
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      children: [
        TextField(
          key: const ValueKey('reauth-password'),
          controller: _password,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          inputFormatters: [
            LengthLimitingTextInputFormatter(maxPasswordLength),
          ],
          decoration: InputDecoration(
            labelText: Strings.fieldPassword,
            error: fieldError(
              _passwordError == null ? null : accountErrorText(_passwordError!),
            ),
            suffixIcon: IconButton(
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
            key: const ValueKey('reauth-error'),
            child: ErrorBanner(_error!),
          ),
          const SizedBox(height: 12),
        ],
        KeyedSubtree(
          key: const ValueKey('reauth-submit'),
          child: BusyButton(
            label: Strings.reauthAction,
            busy: _busy,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
