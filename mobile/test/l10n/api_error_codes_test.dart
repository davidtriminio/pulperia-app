import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

/// Todos los códigos estables que la API puede devolver (rechazos de
/// operaciones, errores de cuentas, negocios, equipo e invitaciones). Si la
/// API añade uno, se añade aquí y en `error_messages.dart` (RNF-5).
const apiCodes = [
  'account_not_found',
  'already_member',
  'amount_invalid_format',
  'amount_mode_invalid',
  'amount_not_positive',
  'amount_not_whole',
  'amount_too_large',
  'amount_too_many_decimals',
  'base_version_required',
  'batch_too_large',
  'business_name_required',
  'business_not_found',
  'business_required',
  'client_not_found',
  'description_too_long',
  'duplicate_item_id',
  'email_invalid',
  'email_taken',
  'entity_already_exists',
  'fiado_empty',
  'fiado_not_found',
  'forbidden',
  'invalid_credentials',
  'invalid_invitation_code',
  'invalid_payload',
  'invalid_refresh_token',
  'invalid_request',
  'invitation_already_pending',
  'invitation_not_found',
  'invitation_not_invitee',
  'invitation_not_pending',
  'item_unit_unknown',
  'mode_downgrade_not_allowed',
  'name_required',
  'note_too_long',
  'op_id_in_use',
  'password_too_long',
  'password_too_short',
  'payment_not_found',
  'phone_invalid_format',
  'product_name_required',
  'product_not_found',
  'product_unit_unknown',
  'quantity_invalid_format',
  'quantity_mode_invalid',
  'quantity_not_positive',
  'quantity_not_whole',
  'quantity_too_large',
  'quantity_too_many_decimals',
  'subtotal_mismatch',
  'team_already_owner',
  'team_last_owner',
  'team_member_not_active',
  'team_member_not_found',
  'too_many_attempts',
  'too_many_items',
  'total_mismatch',
  'unauthorized',
  'unknown_operation',
  'version_conflict',
];

void main() {
  test('ningún código de la API queda sin mensaje en español (RNF-5)', () {
    final missing = [
      for (final code in apiCodes)
        if (errorMessageForCode(code) == null) code,
    ];

    expect(missing, isEmpty);
  });

  test('ningún mensaje es el genérico ni está vacío', () {
    for (final code in apiCodes) {
      final message = errorMessageForCode(code)!;
      expect(message.trim(), isNotEmpty, reason: code);
      expect(message, isNot(Strings.errorUnexpected), reason: code);
      // Nada de códigos a la vista del usuario.
      expect(message, isNot(contains('_')), reason: code);
    }
  });

  test('los códigos de los ejemplos compartidos están cubiertos', () {
    final codes = <String>{};
    for (final file in Directory('../shared/examples').listSync()) {
      if (file is! File || !file.path.endsWith('.json')) {
        continue;
      }
      void walk(Object? node) {
        if (node is Map<String, dynamic>) {
          for (final entry in node.entries) {
            if ((entry.key == 'code') && entry.value is String) {
              codes.add(entry.value as String);
            }
            if (entry.key == 'codes' && entry.value is List) {
              codes.addAll((entry.value as List).whereType<String>());
            }
            walk(entry.value);
          }
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(jsonDecode(file.readAsStringSync()));
    }
    // En los ejemplos `code` también es el código de invitación (8 símbolos).
    final candidates = codes.where((c) => c.contains('_')).toList();

    expect(candidates, isNotEmpty);
    for (final code in candidates) {
      expect(errorMessageForCode(code), isNotNull, reason: code);
    }
  });

  test(
    'un ApiException usa el mensaje de su código y uno desconocido el genérico',
    () {
      expect(
        errorMessage(const ApiException(409, 'team_last_owner')),
        errorMessageForCode('team_last_owner'),
      );
      expect(
        errorMessage(const ApiException(400, 'algo_nuevo')),
        Strings.errorUnexpected,
      );
      // Un fallo del servidor sin código conocido dice que es del servidor.
      expect(
        errorMessage(const ApiException(500, ApiException.unexpectedResponse)),
        Strings.errorServer,
      );
    },
  );
}
