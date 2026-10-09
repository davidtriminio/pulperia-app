import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';

import 'fake_api.dart';

/// Un servidor falso con las reglas reales de la sincronización (plan,
/// sección 4): idempotencia por `opId`, versión por registro, rechazo por
/// conflicto, anulaciones idempotentes y un `seq` por cambio. Lo comparten
/// varios dispositivos simulados (T099). Solo entiende las operaciones de
/// clientes, fiados y abonos.
class FakeServer extends FakeApi {
  FakeServer({super.now});

  int _seq = 0;
  final Map<String, OperationResult> _processed = {};

  /// Estado actual de cada registro y el `seq` de su último cambio.
  final Map<String, _Row> _rows = {};

  /// Cuántas operaciones se aplicaron de verdad (sin contar duplicadas).
  int applied = 0;

  _Row? _row(String type, String id) => _rows['$type:$id'];

  @override
  Future<List<OperationResult>> push(
    String accessToken,
    String businessId,
    List<PushOperation> operations,
  ) async {
    enter('push');
    pushed.add(operations);
    final results = <OperationResult>[];
    for (final op in operations) {
      final known = _processed[op.opId];
      if (known != null) {
        results.add(
          known.status == OperationStatus.applied
              ? OperationResult(
                  opId: op.opId,
                  status: OperationStatus.duplicate,
                )
              : known,
        );
        continue;
      }
      final result = _apply(op);
      _processed[op.opId] = result;
      if (result.status == OperationStatus.applied) {
        applied++;
      }
      results.add(result);
    }
    return results;
  }

  OperationResult _ok(PushOperation op) =>
      OperationResult(opId: op.opId, status: OperationStatus.applied);

  OperationResult _no(PushOperation op, String code) => OperationResult(
    opId: op.opId,
    status: OperationStatus.rejected,
    code: code,
    codes: [code],
  );

  static const _clientFields = [
    'name',
    'characterId',
    'skinId',
    'backgroundId',
    'phone',
    'address',
    'note',
  ];

  OperationResult _apply(PushOperation op) {
    final p = op.payload;
    switch (op.type) {
      case 'client.create':
        _rows['client:${op.entityId}'] = _Row(++_seq, {
          'id': op.entityId,
          for (final k in _clientFields) k: p[k],
          'archived': false,
          'version': 1,
          'createdAt': op.createdAt,
        });
        return _ok(op);
      case 'client.update' || 'client.archive' || 'client.restore':
        final row = _row('client', op.entityId);
        if (row == null) {
          return _no(op, 'client_not_found');
        }
        if (row.data['version'] != op.baseVersion) {
          return _no(op, 'version_conflict');
        }
        if (op.type == 'client.update') {
          for (final k in _clientFields) {
            row.data[k] = p[k];
          }
        } else {
          row.data['archived'] = op.type == 'client.archive';
        }
        row.data['version'] = (row.data['version'] as int) + 1;
        row.seq = ++_seq;
        return _ok(op);
      case 'fiado.create':
        if (_row('client', p['clientId'] as String) == null) {
          return _no(op, 'client_not_found');
        }
        _rows['fiado:${op.entityId}'] = _Row(++_seq, {
          'id': op.entityId,
          'clientId': p['clientId'],
          'total': p['total'],
          'occurredAt': DateTime.parse(p['occurredAt'] as String),
          'items': p['items'],
          'annulledAt': null,
          'serverSeq': _seq,
        });
        return _ok(op);
      case 'payment.create':
        if (_row('client', p['clientId'] as String) == null) {
          return _no(op, 'client_not_found');
        }
        _rows['payment:${op.entityId}'] = _Row(++_seq, {
          'id': op.entityId,
          'clientId': p['clientId'],
          'amount': p['amount'],
          'occurredAt': DateTime.parse(p['occurredAt'] as String),
          'annulledAt': null,
          'serverSeq': _seq,
        });
        return _ok(op);
      case 'fiado.annul' || 'payment.annul':
        final type = op.type == 'fiado.annul' ? 'fiado' : 'payment';
        final row = _row(type, op.entityId);
        if (row == null) {
          return _no(op, '${type}_not_found');
        }
        if (row.data['annulledAt'] == null) {
          row.data['annulledAt'] = op.createdAt;
          row.seq = ++_seq;
        }
        return _ok(op);
    }
    return _no(op, 'unsupported_operation');
  }

  @override
  Future<PullPage> pull(
    String accessToken,
    String businessId, {
    required int cursor,
    int? limit,
  }) async {
    enter('pull');
    pulledFrom.add(cursor);
    final after = _rows.entries.where((e) => e.value.seq > cursor).toList()
      ..sort((a, b) => a.value.seq.compareTo(b.value.seq));
    final page = after.take(limit ?? pageSize).toList();
    return PullPage(
      cursor: page.isEmpty ? cursor : page.last.value.seq,
      hasMore: after.length > page.length,
      changes: [for (final e in page) _change(e.key, e.value)],
    );
  }

  RemoteChange _change(String key, _Row row) {
    final d = row.data;
    final when = DateTime.utc(2026, 10, 9, 14);
    final entity = switch (key.split(':').first) {
      'client' => RemoteClient(
        id: d['id']! as String,
        name: d['name']! as String,
        characterId: d['characterId']! as String,
        skinId: d['skinId']! as String,
        backgroundId: d['backgroundId']! as String,
        phone: d['phone'] as String?,
        address: d['address'] as String?,
        note: d['note'] as String?,
        archived: d['archived']! as bool,
        version: d['version']! as int,
        createdBy: 'u-9',
        createdAt: d['createdAt']! as DateTime,
        updatedAt: when,
      ),
      'fiado' => RemoteFiado(
        id: d['id']! as String,
        clientId: d['clientId']! as String,
        total: d['total']! as int,
        occurredAt: d['occurredAt']! as DateTime,
        serverSeq: d['serverSeq']! as int,
        createdBy: 'u-9',
        annulledAt: d['annulledAt'] as DateTime?,
        annulledBy: d['annulledAt'] == null ? null : 'u-9',
        items: [
          for (final i in d['items']! as List<dynamic>)
            RemoteFiadoItem(
              id: (i as Map<String, dynamic>)['id'] as String,
              productId: i['productId'] as String?,
              description: i['description'] as String,
              quantity: i['quantity'] as int,
              unit: SaleUnit.fromId(i['unit'] as String),
              unitPrice: i['unitPrice'] as int,
              subtotal: i['subtotal'] as int,
            ),
        ],
      ),
      _ => RemotePayment(
        id: d['id']! as String,
        clientId: d['clientId']! as String,
        amount: d['amount']! as int,
        occurredAt: d['occurredAt']! as DateTime,
        serverSeq: d['serverSeq']! as int,
        createdBy: 'u-9',
        annulledAt: d['annulledAt'] as DateTime?,
        annulledBy: d['annulledAt'] == null ? null : 'u-9',
      ),
    };
    return RemoteChange(seq: row.seq, entity: entity);
  }
}

class _Row {
  _Row(this.seq, this.data);

  int seq;
  final Map<String, Object?> data;
}
