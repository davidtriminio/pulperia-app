import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/app.dart';
import 'package:pulperia_mobile/app/providers.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/l10n/error_messages.dart';
import 'package:pulperia_mobile/l10n/strings.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;

  setUp(() {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore();
    api.team = const [
      TeamMember(userId: 'u-1', email: 'ana@correo.com', role: Role.owner),
      TeamMember(userId: 'u-2', email: 'beto@correo.com', role: Role.employee),
      TeamMember(userId: 'u-3', email: 'cata@correo.com', role: Role.owner),
    ];
  });

  tearDown(() => db.close());

  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapKey(WidgetTester tester, String name) async {
    await tester.ensureVisible(key(name));
    await tester.tap(key(name));
    await settle(tester);
  }

  Future<void> pumpApp(WidgetTester tester, {Role role = Role.owner}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final business = remoteBusiness('b-1', role: role);
    store.session = StoredSession(
      userId: 'u-1',
      email: 'ana@correo.com',
      tokens: tokensAt(api.now),
      activeBusiness: business,
    );
    await tester.runAsync(() => insertBusiness(db, 'b-1', name: business.name));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pulperiaApiProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => api.now),
          syncWaitProvider.overrideWithValue((_) async {}),
        ],
        child: const PulperiaApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> openTeam(WidgetTester tester) async {
    await tapKey(tester, 'home-menu');
    await tapKey(tester, 'menu-team');
  }

  group('entrada (RF-13)', () {
    testWidgets('el dueño ve Equipo en el menú', (tester) async {
      await pumpApp(tester);
      await tapKey(tester, 'home-menu');

      expect(key('menu-team'), findsOne);
    });

    testWidgets('el empleado no ve la sección', (tester) async {
      await pumpApp(tester, role: Role.employee);
      await tapKey(tester, 'home-menu');

      expect(key('menu-team'), findsNothing);
    });
  });

  group('equipo (RF-11, RF-70, RF-71)', () {
    testWidgets('lista a los miembros con su rol y se marca a uno mismo', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTeam(tester);

      expect(find.text('beto@correo.com'), findsOne);
      expect(find.text('cata@correo.com'), findsOne);
      expect(find.text('ana@correo.com'), findsOne);
      expect(key('member-role-u-2'), findsOne);
      expect(
        tester.widget<Text>(key('member-role-u-2')).data,
        Strings.roleEmployee,
      );
      expect(
        tester.widget<Text>(key('member-role-u-1')).data,
        Strings.roleOwner,
      );
      expect(find.text(Strings.youMarker), findsOne);
    });

    testWidgets('promover a un empleado lo hace dueño', (tester) async {
      await pumpApp(tester);
      await openTeam(tester);

      await tapKey(tester, 'member-menu-u-2');
      await tapKey(tester, 'member-promote-u-2');
      await tapKey(tester, 'confirm-yes');

      expect(api.team.firstWhere((m) => m.userId == 'u-2').role, Role.owner);
      expect(
        tester.widget<Text>(key('member-role-u-2')).data,
        Strings.roleOwner,
      );
    });

    testWidgets('quitar a un miembro pide confirmación y lo saca', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTeam(tester);

      await tapKey(tester, 'member-menu-u-2');
      await tapKey(tester, 'member-remove-u-2');
      await tapKey(tester, 'confirm-no');
      expect(api.team.any((m) => m.userId == 'u-2'), isTrue);

      await tapKey(tester, 'member-menu-u-2');
      await tapKey(tester, 'member-remove-u-2');
      await tapKey(tester, 'confirm-yes');

      expect(api.team.any((m) => m.userId == 'u-2'), isFalse);
      expect(find.text('beto@correo.com'), findsNothing);
    });

    testWidgets('el último dueño no se puede quitar (RF-71)', (tester) async {
      api.team = const [
        TeamMember(userId: 'u-1', email: 'ana@correo.com', role: Role.owner),
        TeamMember(
          userId: 'u-2',
          email: 'beto@correo.com',
          role: Role.employee,
        ),
      ];
      await pumpApp(tester);
      await openTeam(tester);

      // Uno mismo, siendo el único dueño, no tiene acciones.
      expect(key('member-menu-u-1'), findsNothing);
      // El empleado sí.
      expect(key('member-menu-u-2'), findsOne);
    });

    testWidgets('si el servidor rechaza quitar al último dueño se avisa', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTeam(tester);
      api.failures['removeMember'] = const ApiException(
        409,
        'team_last_owner',
        ['team_last_owner'],
      );

      await tapKey(tester, 'member-menu-u-3');
      await tapKey(tester, 'member-remove-u-3');
      await tapKey(tester, 'confirm-yes');

      expect(find.text(errorMessageForCode('team_last_owner')!), findsOne);
    });

    testWidgets('sin conexión muestra el error y permite reintentar', (
      tester,
    ) async {
      api.failures['listTeam'] = const NetworkException();
      await pumpApp(tester);
      await openTeam(tester);

      expect(find.text(Strings.errorOffline), findsOne);

      api.failures.remove('listTeam');
      await tapKey(tester, 'team-retry');

      expect(find.text('beto@correo.com'), findsOne);
    });
  });

  group('invitaciones (RF-10, RF-69)', () {
    testWidgets('invitar por correo la deja pendiente en la lista', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTeam(tester);

      await tapKey(tester, 'team-invite');
      await tester.enterText(key('invite-email'), 'dina@correo.com');
      await tester.pump();
      await tapKey(tester, 'invite-send');

      expect(api.businessInvitations.single.email, 'dina@correo.com');
      expect(find.text('dina@correo.com'), findsOne);
      expect(find.text(Strings.inviteSent), findsOne);
    });

    testWidgets('un correo inválido se marca sin llamar al servidor', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTeam(tester);

      await tapKey(tester, 'team-invite');
      await tester.enterText(key('invite-email'), 'sin-arroba');
      await tester.pump();
      await tapKey(tester, 'invite-send');

      expect(find.text(Strings.emailInvalid), findsOne);
      expect(api.count('invite'), 0);
    });

    testWidgets('cancelar una invitación pendiente la quita', (tester) async {
      api.businessInvitations = const [
        BusinessInvitation(
          id: 'inv-9',
          email: 'dina@correo.com',
          code: 'AAAA1111',
          status: InvitationStatus.pending,
        ),
      ];
      await pumpApp(tester);
      await openTeam(tester);
      expect(find.text('dina@correo.com'), findsOne);

      await tapKey(tester, 'invitation-cancel-inv-9');
      await tapKey(tester, 'confirm-yes');

      expect(api.businessInvitations, isEmpty);
      expect(find.text('dina@correo.com'), findsNothing);
    });

    testWidgets('una invitación repetida se rechaza con su mensaje', (
      tester,
    ) async {
      api.businessInvitations = const [
        BusinessInvitation(
          id: 'inv-9',
          email: 'dina@correo.com',
          code: 'AAAA1111',
          status: InvitationStatus.pending,
        ),
      ];
      await pumpApp(tester);
      await openTeam(tester);

      await tapKey(tester, 'team-invite');
      await tester.enterText(key('invite-email'), 'dina@correo.com');
      await tester.pump();
      await tapKey(tester, 'invite-send');

      expect(
        find.text(errorMessageForCode('invitation_already_pending')!),
        findsOne,
      );
    });
  });
}
