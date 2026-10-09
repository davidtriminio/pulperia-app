import 'package:pulperia_mobile/data/remote/api_client.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';

/// La sesión guardada en memoria, para los tests.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

/// Tokens de prueba que caducan en [accessFor] y [refreshFor] desde [now].
ApiTokens tokensAt(
  DateTime now, {
  String userId = 'u-1',
  String access = 'access-1',
  String refresh = 'refresh-1',
  Duration accessFor = const Duration(minutes: 15),
  Duration refreshFor = const Duration(days: 90),
}) => ApiTokens(
  userId: userId,
  accessToken: access,
  accessExpiresAt: now.add(accessFor),
  refreshToken: refresh,
  refreshExpiresAt: now.add(refreshFor),
);

RemoteBusiness remoteBusiness(
  String id, {
  String name = 'Pulpería Ana',
  Role role = Role.owner,
  AmountMode amountMode = AmountMode.twoDecimals,
  QuantityMode quantityMode = QuantityMode.fractional,
}) => RemoteBusiness(
  id: id,
  name: name,
  role: role,
  amountMode: amountMode,
  quantityMode: quantityMode,
);

/// Un servidor falso: responde lo que el test configure y recuerda las
/// llamadas. Con [offline] toda llamada falla como si no hubiera red.
class FakeApi implements PulperiaApi {
  FakeApi({DateTime? now}) : now = now ?? DateTime.utc(2026, 10, 9, 15);

  DateTime now;
  bool offline = false;

  /// Si no es null, la siguiente llamada lanza esto (y se limpia).
  Object? failNext;

  /// Un rechazo para cada tipo de llamada, por nombre ('login', 'refresh'...).
  final Map<String, Object> failures = {};

  /// Las llamadas hechas, en orden: `login`, `register`, `refresh`...
  final List<String> calls = [];

  /// Cuántas veces se llamó a cada cosa.
  int count(String name) => calls.where((c) => c == name).length;

  int _tokenCounter = 0;
  String userId = 'u-1';
  String registeredBusinessId = 'b-1';
  List<RemoteBusiness> businesses = [];
  Map<String, String> passwords = {};

  /// Tokens que devolverá la próxima renovación o inicio de sesión.
  ApiTokens Function(DateTime now, String userId, int n)? tokenFactory;

  /// Operaciones y cursor recibidos por sincronización, para tests posteriores.
  final List<List<PushOperation>> pushed = [];

  /// Los cambios que el servidor tiene para entregar por pull, y de a cuántos.
  final List<RemoteChange> serverChanges = [];
  int pageSize = 200;

  /// El cursor con el que se pidió cada página, en orden.
  final List<int> pulledFrom = [];

  /// Resultado de cada operación del lote; null (o sin función) es "aplicada".
  OperationResult? Function(PushOperation op)? pushResult;

  void enter(String name) {
    calls.add(name);
    if (offline) {
      throw const NetworkException('sin red');
    }
    if (failNext != null) {
      final failure = failNext!;
      failNext = null;
      throw failure;
    }
    if (failures[name] case final failure?) {
      throw failure;
    }
  }

  ApiTokens _newTokens() {
    _tokenCounter++;
    return tokenFactory?.call(now, userId, _tokenCounter) ??
        tokensAt(
          now,
          userId: userId,
          access: 'access-$_tokenCounter',
          refresh: 'refresh-$_tokenCounter',
        );
  }

  @override
  Future<RegisteredAccount> register({
    required String email,
    required String password,
    required String businessName,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    enter('register');
    passwords[email] = password;
    businesses = [
      ...businesses,
      RemoteBusiness(
        id: registeredBusinessId,
        name: businessName,
        role: Role.owner,
        amountMode: amountMode,
        quantityMode: quantityMode,
      ),
    ];
    return RegisteredAccount(userId: userId, businessId: registeredBusinessId);
  }

  @override
  Future<ApiTokens> login(String email, String password) async {
    enter('login');
    if (passwords.isNotEmpty && passwords[email] != password) {
      throw const ApiException(401, 'invalid_credentials', [
        'invalid_credentials',
      ]);
    }
    return _newTokens();
  }

  @override
  Future<ApiTokens> refresh(String refreshToken) async {
    enter('refresh');
    return _newTokens();
  }

  @override
  Future<void> logout(String accessToken) async {
    enter('logout');
  }

  @override
  Future<List<RemoteBusiness>> listBusinesses(String accessToken) async {
    enter('listBusinesses');
    return List.of(businesses);
  }

  @override
  Future<RemoteBusiness> createBusiness(
    String accessToken, {
    required String name,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    enter('createBusiness');
    final business = RemoteBusiness(
      id: 'b-${businesses.length + 1}',
      name: name,
      role: Role.owner,
      amountMode: amountMode,
      quantityMode: quantityMode,
    );
    businesses = [...businesses, business];
    return business;
  }

  // --- Ajustes, equipo e invitaciones (en memoria) ---

  BusinessSettings settings = const BusinessSettings(
    name: 'Pulpería Ana',
    amountMode: AmountMode.twoDecimals,
    quantityMode: QuantityMode.fractional,
  );
  List<TeamMember> team = [];
  List<BusinessInvitation> businessInvitations = [];
  List<InvitationOffer> offers = [];

  /// Código -> negocio al que da entrada.
  Map<String, RemoteBusiness> redeemable = {};
  int _inviteCounter = 0;

  @override
  Future<BusinessSettings> getSettings(
    String accessToken,
    String businessId,
  ) async {
    enter('getSettings');
    return settings;
  }

  @override
  Future<BusinessSettings> updateSettings(
    String accessToken,
    String businessId, {
    String? name,
    AmountMode? amountMode,
    QuantityMode? quantityMode,
  }) async {
    enter('updateSettings');
    if ((amountMode == AmountMode.integer &&
            settings.amountMode == AmountMode.twoDecimals) ||
        (quantityMode == QuantityMode.integer &&
            settings.quantityMode == QuantityMode.fractional)) {
      throw const ApiException(400, 'mode_downgrade_not_allowed', [
        'mode_downgrade_not_allowed',
      ]);
    }
    settings = BusinessSettings(
      name: name ?? settings.name,
      amountMode: amountMode ?? settings.amountMode,
      quantityMode: quantityMode ?? settings.quantityMode,
    );
    return settings;
  }

  @override
  Future<List<TeamMember>> listTeam(
    String accessToken,
    String businessId,
  ) async {
    enter('listTeam');
    return List.of(team);
  }

  @override
  Future<void> promote(
    String accessToken,
    String businessId,
    String userId,
  ) async {
    enter('promote');
    team = [
      for (final m in team)
        m.userId == userId
            ? TeamMember(userId: m.userId, email: m.email, role: Role.owner)
            : m,
    ];
  }

  @override
  Future<void> removeMember(
    String accessToken,
    String businessId,
    String userId,
  ) async {
    enter('removeMember');
    final target = team.where((m) => m.userId == userId).firstOrNull;
    final owners = team.where((m) => m.role == Role.owner).length;
    if (target != null && target.role == Role.owner && owners <= 1) {
      throw const ApiException(409, 'team_last_owner', ['team_last_owner']);
    }
    team = [
      for (final m in team)
        if (m.userId != userId) m,
    ];
  }

  @override
  Future<List<BusinessInvitation>> listBusinessInvitations(
    String accessToken,
    String businessId,
  ) async {
    enter('listBusinessInvitations');
    return List.of(businessInvitations);
  }

  @override
  Future<BusinessInvitation> invite(
    String accessToken,
    String businessId, {
    String? email,
  }) async {
    enter('invite');
    if (email != null &&
        businessInvitations.any(
          (i) => i.email == email && i.status == InvitationStatus.pending,
        )) {
      throw const ApiException(409, 'invitation_already_pending', [
        'invitation_already_pending',
      ]);
    }
    _inviteCounter++;
    final invitation = BusinessInvitation(
      id: 'inv-$_inviteCounter',
      email: email,
      code: 'CODE${_inviteCounter.toString().padLeft(4, '0')}',
      status: InvitationStatus.pending,
    );
    businessInvitations = [...businessInvitations, invitation];
    return invitation;
  }

  @override
  Future<void> cancelInvitation(
    String accessToken,
    String businessId,
    String invitationId,
  ) async {
    enter('cancelInvitation');
    businessInvitations = [
      for (final i in businessInvitations)
        if (i.id != invitationId) i,
    ];
  }

  @override
  Future<List<InvitationOffer>> listInvitations(String accessToken) async {
    enter('listInvitations');
    return List.of(offers);
  }

  @override
  Future<RemoteBusiness> acceptInvitation(
    String accessToken,
    String invitationId,
  ) async {
    enter('acceptInvitation');
    final offer = offers.where((o) => o.id == invitationId).firstOrNull;
    if (offer == null) {
      throw const ApiException(404, 'invitation_not_found', [
        'invitation_not_found',
      ]);
    }
    offers = [
      for (final o in offers)
        if (o.id != invitationId) o,
    ];
    final business = RemoteBusiness(
      id: offer.businessId,
      name: offer.businessName,
      role: Role.employee,
      amountMode: AmountMode.twoDecimals,
      quantityMode: QuantityMode.fractional,
    );
    businesses = [...businesses, business];
    return business;
  }

  @override
  Future<void> rejectInvitation(String accessToken, String invitationId) async {
    enter('rejectInvitation');
    offers = [
      for (final o in offers)
        if (o.id != invitationId) o,
    ];
  }

  @override
  Future<RemoteBusiness> redeemInvitationCode(
    String accessToken,
    String code,
  ) async {
    enter('redeemInvitationCode');
    final business = redeemable.remove(code);
    if (business == null) {
      throw const ApiException(404, 'invalid_invitation_code', [
        'invalid_invitation_code',
      ]);
    }
    businesses = [...businesses, business];
    return business;
  }

  @override
  Future<List<OperationResult>> push(
    String accessToken,
    String businessId,
    List<PushOperation> operations,
  ) async {
    enter('push');
    pushed.add(operations);
    return [
      for (final o in operations)
        pushResult?.call(o) ??
            OperationResult(opId: o.opId, status: OperationStatus.applied),
    ];
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
    final after = serverChanges.where((c) => c.seq > cursor).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final page = after.take(limit ?? pageSize).toList();
    return PullPage(
      cursor: page.isEmpty ? cursor : page.last.seq,
      hasMore: after.length > page.length,
      changes: page,
    );
  }
}

final _serverTime = DateTime.utc(2026, 10, 9, 14);

RemoteChange clientChange(
  int seq,
  String id, {
  String name = 'Ana López',
  int version = 1,
  bool archived = false,
}) => RemoteChange(
  seq: seq,
  entity: RemoteClient(
    id: id,
    name: name,
    characterId: 'char-01',
    skinId: 'skin-1',
    backgroundId: 'bg-01',
    phone: null,
    address: null,
    note: null,
    archived: archived,
    version: version,
    createdBy: 'u-9',
    createdAt: _serverTime,
    updatedAt: _serverTime,
  ),
);

RemoteChange productChange(
  int seq,
  String id, {
  String name = 'Arroz',
  int price = 2500,
  int version = 1,
}) => RemoteChange(
  seq: seq,
  entity: RemoteProduct(
    id: id,
    name: name,
    price: price,
    unit: SaleUnit.pound,
    previousPrice: null,
    priceChangedAt: null,
    archived: false,
    version: version,
    createdBy: 'u-9',
    createdAt: _serverTime,
  ),
);

RemoteChange fiadoChange(
  int seq,
  String id,
  String clientId, {
  int total = 1400,
  DateTime? annulledAt,
  List<RemoteFiadoItem>? items,
}) => RemoteChange(
  seq: seq,
  entity: RemoteFiado(
    id: id,
    clientId: clientId,
    total: total,
    occurredAt: _serverTime,
    serverSeq: seq,
    createdBy: 'u-9',
    annulledAt: annulledAt,
    annulledBy: annulledAt == null ? null : 'u-9',
    items:
        items ??
        [
          RemoteFiadoItem(
            id: '$id-i1',
            productId: null,
            description: 'Arroz',
            quantity: 500,
            unit: SaleUnit.pound,
            unitPrice: 2800,
            subtotal: 1400,
          ),
        ],
  ),
);

RemoteChange paymentChange(
  int seq,
  String id,
  String clientId, {
  int amount = 500,
  DateTime? annulledAt,
}) => RemoteChange(
  seq: seq,
  entity: RemotePayment(
    id: id,
    clientId: clientId,
    amount: amount,
    occurredAt: _serverTime,
    serverSeq: seq,
    createdBy: 'u-9',
    annulledAt: annulledAt,
    annulledBy: annulledAt == null ? null : 'u-9',
  ),
);
