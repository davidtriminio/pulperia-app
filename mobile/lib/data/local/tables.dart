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
}
