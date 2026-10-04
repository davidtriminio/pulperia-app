import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

final created = DateTime.utc(2026, 10, 2, 15, 30, 45);

AppDatabase openDb() => AppDatabase(NativeDatabase.memory());

Future<void> insertBusiness(
  AppDatabase db,
  String id, {
  String name = 'Pulpería Don Chepe',
}) => db
    .into(db.businesses)
    .insert(
      BusinessesCompanion.insert(
        id: id,
        name: name,
        amountMode: 'two_decimals',
        quantityMode: 'fractional',
        createdAt: created,
      ),
    );

Future<void> insertClient(
  AppDatabase db,
  String id,
  String businessId, {
  String name = 'Ana',
}) => db
    .into(db.clients)
    .insert(
      ClientsCompanion.insert(
        id: id,
        businessId: businessId,
        name: name,
        characterId: 'char-01',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
        createdBy: 'u-1',
        createdAt: created,
        updatedAt: created,
      ),
    );

Future<void> insertProduct(
  AppDatabase db,
  String id,
  String businessId, {
  int price = 2500,
}) => db
    .into(db.products)
    .insert(
      ProductsCompanion.insert(
        id: id,
        businessId: businessId,
        name: 'Arroz',
        price: price,
        createdBy: 'u-1',
        createdAt: created,
      ),
    );

Future<void> insertFiado(
  AppDatabase db,
  String id,
  String businessId,
  String clientId, {
  int total = 5000,
  DateTime? occurredAt,
  DateTime? annulledAt,
  String? annulledBy,
  int? serverSeq,
}) => db
    .into(db.fiados)
    .insert(
      FiadosCompanion.insert(
        id: id,
        businessId: businessId,
        clientId: clientId,
        total: total,
        occurredAt: occurredAt ?? created,
        createdBy: 'u-1',
        annulledAt: Value(annulledAt),
        annulledBy: Value(annulledBy),
        serverSeq: Value(serverSeq),
      ),
    );

Future<void> insertFiadoItem(
  AppDatabase db,
  String id,
  String businessId,
  String fiadoId, {
  String? productId,
  String description = 'Arroz',
  int quantity = 1000,
  int unitPrice = 2500,
  int subtotal = 2500,
}) => db
    .into(db.fiadoItems)
    .insert(
      FiadoItemsCompanion.insert(
        id: id,
        businessId: businessId,
        fiadoId: fiadoId,
        productId: Value(productId),
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
      ),
    );

Future<void> insertPayment(
  AppDatabase db,
  String id,
  String businessId,
  String clientId, {
  int amount = 3000,
  DateTime? occurredAt,
  DateTime? annulledAt,
  String? annulledBy,
  int? serverSeq,
}) => db
    .into(db.payments)
    .insert(
      PaymentsCompanion.insert(
        id: id,
        businessId: businessId,
        clientId: clientId,
        amount: amount,
        occurredAt: occurredAt ?? created,
        createdBy: 'u-1',
        annulledAt: Value(annulledAt),
        annulledBy: Value(annulledBy),
        serverSeq: Value(serverSeq),
      ),
    );
