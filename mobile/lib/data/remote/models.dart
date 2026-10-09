import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/catalog/sale_unit.dart';

/// Modelos del contrato de la API (`shared/openapi.json`). Se leen con
/// `fromJson` estricto: un campo ausente o de otro tipo lanza, y el cliente lo
/// convierte en una respuesta inválida (D-17).

DateTime _date(Object? value) => DateTime.parse(value as String).toUtc();

DateTime? _dateOrNull(Object? value) => value == null ? null : _date(value);

/// Tokens de una sesión (inicio de sesión y renovación).
final class ApiTokens {
  const ApiTokens({
    required this.userId,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  factory ApiTokens.fromJson(Map<String, dynamic> json) => ApiTokens(
    userId: json['userId'] as String,
    accessToken: json['accessToken'] as String,
    accessExpiresAt: _date(json['accessExpiresAt']),
    refreshToken: json['refreshToken'] as String,
    refreshExpiresAt: _date(json['refreshExpiresAt']),
  );

  final String userId;
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
}

/// Lo que devuelve el registro: no trae tokens, hay que iniciar sesión después.
final class RegisteredAccount {
  const RegisteredAccount({required this.userId, required this.businessId});

  factory RegisteredAccount.fromJson(Map<String, dynamic> json) =>
      RegisteredAccount(
        userId: json['userId'] as String,
        businessId: json['businessId'] as String,
      );

  final String userId;
  final String businessId;
}

/// Un negocio del usuario con el rol que tiene en él (RF-5, RF-6).
final class RemoteBusiness {
  const RemoteBusiness({
    required this.id,
    required this.name,
    required this.role,
    required this.amountMode,
    required this.quantityMode,
  });

  factory RemoteBusiness.fromJson(Map<String, dynamic> json) => RemoteBusiness(
    id: json['id'] as String,
    name: json['name'] as String,
    role: Role.fromId(json['role'] as String),
    amountMode: AmountMode.fromId(json['amountMode'] as String),
    quantityMode: QuantityMode.fromId(json['quantityMode'] as String),
  );

  final String id;
  final String name;
  final Role role;
  final AmountMode amountMode;
  final QuantityMode quantityMode;
}

/// Una operación de la cola tal como viaja en un lote (plan 4.1).
final class PushOperation {
  const PushOperation({
    required this.opId,
    required this.type,
    required this.entityId,
    required this.payload,
    required this.createdAt,
    this.baseVersion,
  });

  final String opId;
  final String type;
  final String entityId;
  final Map<String, dynamic> payload;
  final int? baseVersion;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'opId': opId,
    'type': type,
    'entityId': entityId,
    'payload': payload,
    'baseVersion': baseVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

enum OperationStatus {
  applied('applied'),
  duplicate('duplicate'),
  rejected('rejected');

  const OperationStatus(this.id);

  final String id;

  static OperationStatus fromId(String id) => values.firstWhere(
    (s) => s.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'estado desconocido'),
  );
}

/// Qué pasó con una operación del lote (RF-52, RF-53).
final class OperationResult {
  const OperationResult({
    required this.opId,
    required this.status,
    this.code,
    this.codes = const [],
  });

  factory OperationResult.fromJson(Map<String, dynamic> json) =>
      OperationResult(
        opId: json['opId'] as String,
        status: OperationStatus.fromId(json['status'] as String),
        code: json['code'] as String?,
        codes: [
          for (final c in (json['codes'] as List<dynamic>? ?? const []))
            c as String,
        ],
      );

  final String opId;
  final OperationStatus status;

  /// El código principal del rechazo; null si no se rechazó.
  final String? code;
  final List<String> codes;
}

/// Un registro recibido por el pull: la versión actual completa del servidor.
sealed class RemoteEntity {
  const RemoteEntity();
}

final class RemoteClient extends RemoteEntity {
  const RemoteClient({
    required this.id,
    required this.name,
    required this.characterId,
    required this.skinId,
    required this.backgroundId,
    required this.phone,
    required this.address,
    required this.note,
    required this.archived,
    required this.version,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteClient.fromJson(Map<String, dynamic> json) => RemoteClient(
    id: json['id'] as String,
    name: json['name'] as String,
    characterId: json['characterId'] as String,
    skinId: json['skinId'] as String,
    backgroundId: json['backgroundId'] as String,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    note: json['note'] as String?,
    archived: json['archived'] as bool,
    version: json['version'] as int,
    createdBy: json['createdBy'] as String,
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  final String id;
  final String name;
  final String characterId;
  final String skinId;
  final String backgroundId;
  final String? phone;
  final String? address;
  final String? note;
  final bool archived;
  final int version;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class RemoteProduct extends RemoteEntity {
  const RemoteProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.previousPrice,
    required this.priceChangedAt,
    required this.archived,
    required this.version,
    required this.createdBy,
    required this.createdAt,
  });

  factory RemoteProduct.fromJson(Map<String, dynamic> json) => RemoteProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    price: json['price'] as int,
    unit: SaleUnit.fromId(json['unit'] as String),
    previousPrice: json['previousPrice'] as int?,
    priceChangedAt: _dateOrNull(json['priceChangedAt']),
    archived: json['archived'] as bool,
    version: json['version'] as int,
    createdBy: json['createdBy'] as String,
    createdAt: _date(json['createdAt']),
  );

  final String id;
  final String name;
  final int price;
  final SaleUnit unit;
  final int? previousPrice;
  final DateTime? priceChangedAt;
  final bool archived;
  final int version;
  final String createdBy;
  final DateTime createdAt;
}

final class RemoteFiadoItem {
  const RemoteFiadoItem({
    required this.id,
    required this.productId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });

  factory RemoteFiadoItem.fromJson(Map<String, dynamic> json) =>
      RemoteFiadoItem(
        id: json['id'] as String,
        productId: json['productId'] as String?,
        description: json['description'] as String,
        quantity: json['quantity'] as int,
        unit: SaleUnit.fromId(json['unit'] as String),
        unitPrice: json['unitPrice'] as int,
        subtotal: json['subtotal'] as int,
      );

  final String id;
  final String? productId;
  final String description;

  /// En milésimas.
  final int quantity;
  final SaleUnit unit;
  final int unitPrice;
  final int subtotal;
}

final class RemoteFiado extends RemoteEntity {
  const RemoteFiado({
    required this.id,
    required this.clientId,
    required this.total,
    required this.occurredAt,
    required this.serverSeq,
    required this.createdBy,
    required this.annulledAt,
    required this.annulledBy,
    required this.items,
  });

  factory RemoteFiado.fromJson(Map<String, dynamic> json) => RemoteFiado(
    id: json['id'] as String,
    clientId: json['clientId'] as String,
    total: json['total'] as int,
    occurredAt: _date(json['occurredAt']),
    serverSeq: json['serverSeq'] as int?,
    createdBy: json['createdBy'] as String,
    annulledAt: _dateOrNull(json['annulledAt']),
    annulledBy: json['annulledBy'] as String?,
    items: [
      for (final i in json['items'] as List<dynamic>)
        RemoteFiadoItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  final String id;
  final String clientId;
  final int total;
  final DateTime occurredAt;

  /// El orden de llegada al servidor, que desempata el historial (D-18).
  final int? serverSeq;
  final String createdBy;
  final DateTime? annulledAt;
  final String? annulledBy;
  final List<RemoteFiadoItem> items;
}

final class RemotePayment extends RemoteEntity {
  const RemotePayment({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.occurredAt,
    required this.serverSeq,
    required this.createdBy,
    required this.annulledAt,
    required this.annulledBy,
  });

  factory RemotePayment.fromJson(Map<String, dynamic> json) => RemotePayment(
    id: json['id'] as String,
    clientId: json['clientId'] as String,
    amount: json['amount'] as int,
    occurredAt: _date(json['occurredAt']),
    serverSeq: json['serverSeq'] as int?,
    createdBy: json['createdBy'] as String,
    annulledAt: _dateOrNull(json['annulledAt']),
    annulledBy: json['annulledBy'] as String?,
  );

  final String id;
  final String clientId;
  final int amount;
  final DateTime occurredAt;
  final int? serverSeq;
  final String createdBy;
  final DateTime? annulledAt;
  final String? annulledBy;
}

/// Un cambio del pull: qué registro y el `seq` de su último cambio.
final class RemoteChange {
  const RemoteChange({required this.seq, required this.entity});

  factory RemoteChange.fromJson(Map<String, dynamic> json) {
    final data = json['entity'] as Map<String, dynamic>;
    return RemoteChange(
      seq: json['seq'] as int,
      entity: switch (json['type'] as String) {
        'client' => RemoteClient.fromJson(data),
        'product' => RemoteProduct.fromJson(data),
        'fiado' => RemoteFiado.fromJson(data),
        'payment' => RemotePayment.fromJson(data),
        final other => throw ArgumentError.value(
          other,
          'type',
          'tipo de registro desconocido',
        ),
      },
    );
  }

  final int seq;
  final RemoteEntity entity;
}

/// Una página de cambios (plan 4.3): el cursor a pedir después y si hay más.
final class PullPage {
  const PullPage({
    required this.cursor,
    required this.hasMore,
    required this.changes,
  });

  factory PullPage.fromJson(Map<String, dynamic> json) => PullPage(
    cursor: json['cursor'] as int,
    hasMore: json['hasMore'] as bool,
    changes: [
      for (final c in json['changes'] as List<dynamic>)
        RemoteChange.fromJson(c as Map<String, dynamic>),
    ],
  );

  final int cursor;
  final bool hasMore;
  final List<RemoteChange> changes;
}

/// El cuerpo de error de la API: un código estable que la app traduce (RNF-5).
final class ApiError {
  const ApiError({required this.code, required this.codes});

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
    code: json['code'] as String,
    codes: [for (final c in json['codes'] as List<dynamic>) c as String],
  );

  final String code;
  final List<String> codes;
}

/// La API respondió con un error (o con algo que no es el contrato).
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.codes = const []]);

  /// La respuesta no tenía el cuerpo de error del contrato.
  static const unexpectedResponse = 'unexpected_response';

  /// Una respuesta correcta cuyo cuerpo no cumple el contrato.
  static const invalidResponse = 'invalid_response';

  final int status;

  /// El código estable principal.
  final String code;
  final List<String> codes;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// No se pudo hablar con el servidor: sin red, sin ruta o sin respuesta a
/// tiempo. La cola y la sesión no se tocan (RF-56).
class NetworkException implements Exception {
  const NetworkException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'NetworkException($cause)';
}
