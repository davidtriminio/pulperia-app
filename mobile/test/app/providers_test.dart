import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';

import '../support/dev_session.dart';

import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';

import '../support/db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openDb());
  tearDown(() => db.close());

  testWidgets('un ProviderScope con base en memoria da el negocio activo', (
    tester,
  ) async {
    final session = devSessionFor(isRelease: false)!;
    await tester.runAsync(() => seedDevSession(db, session));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeSessionProvider.overrideWithValue(devSessionFor()!),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final business = ref.watch(activeBusinessProvider);
              final user = ref.watch(activeUserProvider);
              return Text(
                business.when(
                  data: (b) => '${b.name}|${b.id}|${user.id}|${user.role.id}',
                  loading: () => 'cargando',
                  error: (e, _) => 'error: $e',
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      find.text(
        '${session.businessName}|${session.businessId}|${session.userId}|owner',
      ),
      findsOneWidget,
    );
  });

  test('el usuario activo es el dueño de la sesión de prueba', () {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeSessionProvider.overrideWithValue(devSessionFor()!),
      ],
    );
    addTearDown(container.dispose);

    final user = container.read(activeUserProvider);

    expect(user.role, Role.owner);
    expect(user.id, devSessionFor(isRelease: false)!.userId);
  });

  test('sin sobrescribir la base falla en vez de abrir una vacía', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(() => container.read(appDatabaseProvider), throwsA(anything));
  });

  test('los repositorios generan ids UUID v7 con newId()', () async {
    final session = devSessionFor(isRelease: false)!;
    await seedDevSession(db, session);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeSessionProvider.overrideWithValue(devSessionFor()!),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(clientRepositoryProvider)
        .create(
          businessId: session.businessId,
          userId: session.userId,
          draft: const ClientDraft(
            name: 'Ana',
            characterId: 'char-01',
            skinId: 'skin-1',
            backgroundId: 'bg-01',
          ),
        );

    final saved = (result as ClientSaved).client;
    expect(
      saved.id,
      matches(RegExp(r'^[0-9a-f-]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab]')),
    );
  });
}
