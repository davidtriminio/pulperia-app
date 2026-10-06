import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/l10n/strings.dart';
import 'package:pulperia_mobile/ui/clients/client_form_screen.dart';
import 'package:pulperia_mobile/ui/widgets/confirm_dialog.dart';

import '../../support/db_fixtures.dart';

void main() {
  late AppDatabase db;
  late String businessId;

  setUp(() {
    db = openDb();
    businessId = devSessionFor(isRelease: false)!.businessId;
  });
  tearDown(() => db.close());

  /// Abre el formulario desde una pantalla anterior, para ver que se cierra.
  Future<void> openForm(WidgetTester tester, {Client? existing}) async {
    await tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClientFormScreen(existing: existing),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
  }

  Future<void> pickAvatar(WidgetTester tester) async {
    final field = find.byKey(const ValueKey('avatar-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    for (final key in ['pick-char-02', 'pick-skin-3', 'pick-bg-11']) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('avatar-continue')));
    await tester.pumpAndSettle();
  }

  /// La base corre en un hilo real: se deja avanzar fuera del reloj falso.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('client-save'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settleDb(tester);
  }

  Future<List<Client>> clients(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.clients).get()))!;

  Future<List<OutboxOp>> outbox(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.outboxOps).get()))!;

  group('crear un cliente (RF-14 a RF-18, RF-73)', () {
    testWidgets('guarda nombre, avatar y datos opcionales y se cierra', (
      tester,
    ) async {
      await openForm(tester);

      await type(tester, 'field-name', '  Ana López ');
      await type(tester, 'field-phone', '90000000');
      await type(tester, 'field-address', 'Frente a la iglesia');
      await type(tester, 'field-note', 'Paga los viernes');
      await pickAvatar(tester);
      await save(tester);

      final saved = (await clients(tester)).single;
      expect(saved.businessId, businessId);
      expect(saved.name, 'Ana López');
      expect(saved.phone, '90000000');
      expect(saved.address, 'Frente a la iglesia');
      expect(saved.note, 'Paga los viernes');
      expect(
        [saved.characterId, saved.skinId, saved.backgroundId],
        ['char-02', 'skin-3', 'bg-11'],
      );
      expect((await outbox(tester)).single.type, 'client.create');
      expect(find.byType(ClientFormScreen), findsNothing);
    });

    testWidgets('teléfono, dirección y nota son opcionales (RF-73)', (
      tester,
    ) async {
      await openForm(tester);

      await type(tester, 'field-name', 'Beto');
      await pickAvatar(tester);
      await save(tester);

      final saved = (await clients(tester)).single;
      expect(saved.phone, isNull);
      expect(saved.address, isNull);
      expect(saved.note, isNull);
    });

    testWidgets('sin nombre indica que es obligatorio y no guarda (RF-15)', (
      tester,
    ) async {
      await openForm(tester);

      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.nameRequired), findsOne);
      expect(await clients(tester), isEmpty);
      expect(find.byType(ClientFormScreen), findsOne);
    });

    testWidgets('un nombre de solo espacios cuenta como vacío', (tester) async {
      await openForm(tester);

      await type(tester, 'field-name', '   ');
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.nameRequired), findsOne);
      expect(await clients(tester), isEmpty);
    });

    testWidgets('sin avatar indica qué falta elegir y no guarda (RF-16)', (
      tester,
    ) async {
      await openForm(tester);

      await type(tester, 'field-name', 'Ana');
      await save(tester);

      expect(find.text(Strings.avatarMissingCharacter), findsOne);
      expect(find.text(Strings.avatarMissingSkin), findsOne);
      expect(find.text(Strings.avatarMissingBackground), findsOne);
      expect(await clients(tester), isEmpty);
    });

    testWidgets('un teléfono inválido indica el formato esperado (RF-77)', (
      tester,
    ) async {
      await openForm(tester);

      await type(tester, 'field-name', 'Ana');
      await type(tester, 'field-phone', '12345678');
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.phoneInvalid), findsOne);
      expect(await clients(tester), isEmpty);
    });

    testWidgets('una nota de 301 caracteres se rechaza con el límite (RF-74)', (
      tester,
    ) async {
      await openForm(tester);

      await type(tester, 'field-name', 'Ana');
      await type(tester, 'field-note', 'x' * 301);
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.noteTooLong), findsOne);
      expect(await clients(tester), isEmpty);
    });

    testWidgets('una nota de 300 caracteres se acepta', (tester) async {
      await openForm(tester);

      await type(tester, 'field-name', 'Ana');
      await type(tester, 'field-note', 'x' * 300);
      await pickAvatar(tester);
      await save(tester);

      expect((await clients(tester)).single.note, 'x' * 300);
    });

    testWidgets('la nota muestra un contador de caracteres (RF-74)', (
      tester,
    ) async {
      await openForm(tester);
      String counter() =>
          tester.widget<Text>(find.byKey(const ValueKey('note-counter'))).data!;

      expect(counter(), '0/300');
      await type(tester, 'field-note', 'hola');
      expect(counter(), '4/300');
      await type(tester, 'field-note', 'x' * 301);
      expect(counter(), '301/300');
      final color = tester
          .widget<Text>(find.byKey(const ValueKey('note-counter')))
          .style
          ?.color;
      expect(
        color,
        Theme.of(tester.element(find.byType(Scaffold).last)).colorScheme.error,
      );
    });

    testWidgets('corregir un error y volver a guardar funciona', (
      tester,
    ) async {
      await openForm(tester);
      await type(tester, 'field-name', 'Ana');
      await pickAvatar(tester);
      await type(tester, 'field-phone', '1');
      await save(tester);
      expect(find.text(Strings.phoneInvalid), findsOne);

      await type(tester, 'field-phone', '80000000');
      await save(tester);

      expect((await clients(tester)).single.phone, '80000000');
    });
  });

  group('aviso de nombre repetido (RF-17)', () {
    Future<void> seedAna(WidgetTester tester) => tester.runAsync(() async {
      await seedDevSession(db, devSessionFor(isRelease: false));
      await insertClient(db, 'c-1', businessId, name: 'Ana López');
    });

    testWidgets('avisa y no guarda hasta que se confirme', (tester) async {
      await seedAna(tester);
      await openForm(tester);

      await type(tester, 'field-name', '  ana lópez ');
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsOne);
      expect(find.byType(ConfirmDialog), findsOne);
      expect(await clients(tester), hasLength(1));
      expect(find.byType(ClientFormScreen), findsOne);
    });

    testWidgets('cancelar el aviso no guarda y deja corregir', (tester) async {
      await seedAna(tester);
      await openForm(tester);
      await type(tester, 'field-name', 'Ana López');
      await pickAvatar(tester);
      await save(tester);

      await tester.tap(find.byKey(const ValueKey('homonym-cancel')));
      await tester.pumpAndSettle();

      expect(find.text(Strings.homonymTitle), findsNothing);
      expect(await clients(tester), hasLength(1));
      expect(find.byType(ClientFormScreen), findsOne);
    });

    testWidgets('confirmar el aviso guarda el homónimo', (tester) async {
      await seedAna(tester);
      await openForm(tester);
      await type(tester, 'field-name', 'Ana López');
      await pickAvatar(tester);
      await save(tester);

      await tester.tap(find.byKey(const ValueKey('homonym-confirm')));
      await settleDb(tester);

      expect(await clients(tester), hasLength(2));
      expect(find.byType(ClientFormScreen), findsNothing);
    });

    testWidgets('también avisa si el homónimo está archivado', (tester) async {
      await seedAna(tester);
      await tester.runAsync(
        () => (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(archived: Value(true)),
        ),
      );
      await openForm(tester);
      await type(tester, 'field-name', 'Ana López');
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsOne);
    });

    testWidgets('no impide dos clientes con el mismo avatar (RF-18)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedDevSession(db, devSessionFor(isRelease: false));
        await insertClient(db, 'c-1', businessId, name: 'Otra');
        await (db.update(db.clients)..where((c) => c.id.equals('c-1'))).write(
          const ClientsCompanion(
            characterId: Value('char-02'),
            skinId: Value('skin-3'),
            backgroundId: Value('bg-11'),
          ),
        );
      });
      await openForm(tester);
      await type(tester, 'field-name', 'Nueva');
      await pickAvatar(tester);
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsNothing);
      expect(await clients(tester), hasLength(2));
    });
  });

  group('editar un cliente (RF-19)', () {
    late Client existing;

    Future<void> seedExisting(WidgetTester tester) async {
      await tester.runAsync(() async {
        await seedDevSession(db, devSessionFor(isRelease: false));
        await insertClient(db, 'c-1', businessId, name: 'Ana');
        await insertClient(db, 'c-2', businessId, name: 'Beto');
        existing = await (db.select(
          db.clients,
        )..where((c) => c.id.equals('c-1'))).getSingle();
      });
    }

    testWidgets('muestra los datos actuales', (tester) async {
      await seedExisting(tester);
      await openForm(tester, existing: existing);

      final name = tester.widget<TextField>(
        find.byKey(const ValueKey('field-name')),
      );
      expect(name.controller!.text, 'Ana');
    });

    testWidgets('guarda los cambios sin tocar el historial', (tester) async {
      await seedExisting(tester);
      await tester.runAsync(
        () => insertFiado(db, 'f-1', businessId, 'c-1', total: 5000),
      );
      await openForm(tester, existing: existing);

      await type(tester, 'field-name', 'Ana María');
      await type(tester, 'field-phone', '90000000');
      await save(tester);

      final stored = (await clients(tester)).firstWhere((c) => c.id == 'c-1');
      expect(stored.name, 'Ana María');
      expect(stored.phone, '90000000');
      expect(stored.version, 2);
      expect(
        (await tester.runAsync(() => db.select(db.fiados).get()))!,
        hasLength(1),
      );
      expect((await outbox(tester)).single.type, 'client.update');
      expect(find.byType(ClientFormScreen), findsNothing);
    });

    testWidgets('guardar sin cambiar el nombre no lo toma por homónimo', (
      tester,
    ) async {
      await seedExisting(tester);
      await openForm(tester, existing: existing);

      await type(tester, 'field-address', 'Barrio Abajo');
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsNothing);
      expect(
        (await clients(tester)).firstWhere((c) => c.id == 'c-1').address,
        'Barrio Abajo',
      );
    });

    testWidgets('renombrar a un nombre ya usado por otro avisa', (
      tester,
    ) async {
      await seedExisting(tester);
      await openForm(tester, existing: existing);

      await type(tester, 'field-name', 'BETO');
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsOne);
      expect(
        (await clients(tester)).firstWhere((c) => c.id == 'c-1').name,
        'Ana',
      );
    });

    testWidgets('cambiar solo mayúsculas del propio nombre no avisa', (
      tester,
    ) async {
      await seedExisting(tester);
      await openForm(tester, existing: existing);

      await type(tester, 'field-name', 'ANA');
      await save(tester);

      expect(find.text(Strings.homonymTitle), findsNothing);
      expect(
        (await clients(tester)).firstWhere((c) => c.id == 'c-1').name,
        'ANA',
      );
    });
  });
}
