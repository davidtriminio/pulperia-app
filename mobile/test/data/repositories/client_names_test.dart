import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late ClientRepository repo;

  setUp(() async {
    db = openDb();
    repo = ClientRepository(db, newId: () => 'x', now: DateTime.now);
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
  });
  tearDown(() => db.close());

  test('devuelve los nombres de activos y archivados del negocio', () async {
    await insertClient(db, 'c-1', 'b-1', name: 'Ana');
    await insertClient(db, 'c-2', 'b-1', name: 'Beto');
    await (db.update(db.clients)..where((c) => c.id.equals('c-2'))).write(
      const ClientsCompanion(archived: Value(true)),
    );

    final names = await repo.clientNames('b-1');

    expect(names.map((c) => c.name), unorderedEquals(['Ana', 'Beto']));
    expect(names.map((c) => c.id), unorderedEquals(['c-1', 'c-2']));
  });

  test('no incluye clientes de otro negocio', () async {
    await insertClient(db, 'c-1', 'b-1', name: 'Ana');
    await insertClient(db, 'c-9', 'b-2', name: 'Ajena');

    final names = await repo.clientNames('b-1');

    expect(names.map((c) => c.name), ['Ana']);
  });

  test('sin clientes devuelve una lista vacía', () async {
    expect(await repo.clientNames('b-1'), isEmpty);
  });
}
