import 'package:drift/drift.dart';

/// Normaliza toda fecha a UTC al guardarla y al leerla: las fechas se
/// almacenan en UTC (AGENTS.md). Sin esto, Drift guardaría la hora local con
/// su desfase.
class UtcDateTimeConverter extends TypeConverter<DateTime, DateTime> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(DateTime fromDb) => fromDb.toUtc();

  @override
  DateTime toSql(DateTime value) => value.toUtc();
}

/// Tablas locales del móvil. Reflejan las del servidor (plan, sección 3) y,
/// salvo `businesses`, todas llevan `business_id` (principio 6). Los ids los
/// genera el cliente (GUID) para poder crear registros sin conexión. El
/// dinero se guarda como entero en la unidad menor (centavos de lempira).

@DataClassName('Business')
class Businesses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `integer` o `two_decimals`.
  TextColumn get amountMode => text().customConstraint(
    "NOT NULL CHECK (amount_mode IN ('integer', 'two_decimals'))",
  )();

  /// `integer` o `fractional`.
  TextColumn get quantityMode => text().customConstraint(
    "NOT NULL CHECK (quantity_mode IN ('integer', 'fractional'))",
  )();
  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Negocios a los que pertenece el usuario del dispositivo, con su rol en
/// cada uno (RF-5, RF-6).
@DataClassName('Membership')
class Memberships extends Table {
  TextColumn get userId => text()();
  TextColumn get businessId => text().references(Businesses, #id)();

  /// `owner` o `employee`.
  TextColumn get role => text().customConstraint(
    "NOT NULL CHECK (role IN ('owner', 'employee'))",
  )();

  @override
  Set<Column> get primaryKey => {userId, businessId};
}

@DataClassName('Client')
@TableIndex(name: 'clients_business', columns: {#businessId})
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get name => text()();
  TextColumn get characterId => text()();
  TextColumn get skinId => text()();
  TextColumn get backgroundId => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Para detectar conflictos al sincronizar ediciones (D-8).
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();
  DateTimeColumn get updatedAt =>
      dateTime().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {id};

  /// Permite que los movimientos referencien (id, business_id) y así no
  /// puedan apuntar a un cliente de otro negocio.
  @override
  List<Set<Column>> get uniqueKeys => [
    {id, businessId},
  ];
}

@DataClassName('Product')
@TableIndex(name: 'products_business', columns: {#businessId})
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get name => text()();

  /// Precio en la unidad menor (centavos de lempira); siempre positivo.
  IntColumn get price =>
      integer().customConstraint('NOT NULL CHECK (price > 0)')();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt =>
      dateTime().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {id, businessId},
  ];
}

/// Un fiado: lo que el cliente se llevó fiado, con o sin detalle de ítems
/// (RF-28, RF-29). Nunca se edita ni se borra: se anula conservando el
/// registro, con quién y cuándo (RF-43, RF-46, principio 11).
@DataClassName('Fiado')
@TableIndex(name: 'fiados_business', columns: {#businessId})
@TableIndex(name: 'fiados_client', columns: {#clientId})
class Fiados extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get clientId => text()();

  /// Total en la unidad menor; con ítems es la suma de sus subtotales,
  /// calculada al crear y nunca recalculada (principio 4).
  IntColumn get total =>
      integer().customConstraint('NOT NULL CHECK (total > 0)')();

  /// Cuándo ocurrió la venta, según el dispositivo que la registró (D-18).
  DateTimeColumn get occurredAt =>
      dateTime().map(const UtcDateTimeConverter())();
  TextColumn get createdBy => text()();
  DateTimeColumn get annulledAt => dateTime().nullable().map(
    NullAwareTypeConverter.wrap(const UtcDateTimeConverter()),
  )();
  TextColumn get annulledBy => text().nullable()();

  /// Orden de llegada al servidor; null mientras no se ha sincronizado.
  IntColumn get serverSeq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {id, businessId},
  ];

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id)',
    'CHECK ((annulled_at IS NULL) = (annulled_by IS NULL))',
  ];
}

/// Un ítem de un fiado: guarda la descripción, la cantidad y el precio
/// unitario del momento de la compra, aunque el producto cambie después
/// (principio 4).
@DataClassName('FiadoItem')
@TableIndex(name: 'fiado_items_fiado', columns: {#fiadoId})
class FiadoItems extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get fiadoId => text()();

  /// Producto del catálogo del que se copió; null en un ítem libre (RF-31).
  TextColumn get productId => text().nullable()();
  TextColumn get description => text()();

  /// Cantidad en milésimas.
  IntColumn get quantity =>
      integer().customConstraint('NOT NULL CHECK (quantity > 0)')();

  /// Precio unitario en la unidad menor.
  IntColumn get unitPrice =>
      integer().customConstraint('NOT NULL CHECK (unit_price > 0)')();

  /// Subtotal ya redondeado según el modo del negocio, en la unidad menor.
  IntColumn get subtotal =>
      integer().customConstraint('NOT NULL CHECK (subtotal > 0)')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (fiado_id, business_id) REFERENCES fiados (id, business_id)',
    'FOREIGN KEY (product_id, business_id) REFERENCES products (id, business_id)',
  ];
}

/// Un abono: reduce el saldo del cliente sin asociarse a ningún fiado
/// (RF-37). Igual que el fiado, solo se anula.
@DataClassName('Payment')
@TableIndex(name: 'payments_business', columns: {#businessId})
@TableIndex(name: 'payments_client', columns: {#clientId})
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get clientId => text()();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();
  DateTimeColumn get occurredAt =>
      dateTime().map(const UtcDateTimeConverter())();
  TextColumn get createdBy => text()();
  DateTimeColumn get annulledAt => dateTime().nullable().map(
    NullAwareTypeConverter.wrap(const UtcDateTimeConverter()),
  )();
  TextColumn get annulledBy => text().nullable()();
  IntColumn get serverSeq => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (client_id, business_id) REFERENCES clients (id, business_id)',
    'CHECK ((annulled_at IS NULL) = (annulled_by IS NULL))',
  ];
}
