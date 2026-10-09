import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import 'auth_widgets.dart';

/// Pide el código de una invitación y entra al negocio (RF-93). Un código
/// malo, ya usado o cancelado da siempre el mismo mensaje (RF-94). Se cierra
/// con `true` si entró.
class RedeemCodeDialog extends ConsumerStatefulWidget {
  const RedeemCodeDialog({super.key});

  @override
  ConsumerState<RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends ConsumerState<RedeemCodeDialog> {
  final _code = TextEditingController();
  String? _fieldError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    final typed = _code.text.trim();
    setState(() {
      _fieldError = typed.isEmpty ? Strings.codeRequired : null;
      _error = null;
    });
    if (typed.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .redeemInvitationCode(typed);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(Strings.redeemTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.redeemHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('redeem-code'),
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: InputDecoration(
              labelText: Strings.fieldCode,
              error: fieldError(_fieldError),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const ValueKey('redeem-error'),
              child: ErrorBanner(_error!),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('redeem-cancel'),
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text(Strings.cancel),
      ),
      FilledButton(
        key: const ValueKey('redeem-send'),
        style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
        onPressed: _busy ? null : _send,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(Strings.redeemSend),
      ),
    ],
  );
}
