import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/ui/theme.dart';
import 'package:pulperia_mobile/ui/widgets/confirm_dialog.dart';

void main() {
  Future<bool?> open(WidgetTester tester) async {
    bool? result;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  icon: Icons.archive_outlined,
                  title: 'Título',
                  body: 'Cuerpo del aviso',
                  confirmLabel: 'Aceptar',
                  cancelLabel: 'Cancelar',
                  confirmKey: const ValueKey('yes'),
                  cancelKey: const ValueKey('no'),
                );
                done = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    return done ? result : null;
  }

  testWidgets('muestra ícono, título, cuerpo y los dos botones', (
    tester,
  ) async {
    await open(tester);

    expect(find.byType(ConfirmDialog), findsOne);
    expect(find.byIcon(Icons.archive_outlined), findsOne);
    expect(find.text('Título'), findsOne);
    expect(find.text('Cuerpo del aviso'), findsOne);
    expect(find.byKey(const ValueKey('yes')), findsOne);
    expect(find.byKey(const ValueKey('no')), findsOne);
  });

  testWidgets('la acción principal va arriba y la secundaria debajo', (
    tester,
  ) async {
    await open(tester);

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('yes'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('no'))).dy),
    );
    expect(find.byKey(const ValueKey('yes')), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('yes')),
        matching: find.text('Aceptar'),
      ),
      findsOne,
    );
  });

  testWidgets('el botón principal es relleno y el secundario es de texto', (
    tester,
  ) async {
    await open(tester);

    expect(
      tester.widget(find.byKey(const ValueKey('yes'))),
      isA<FilledButton>(),
    );
    expect(tester.widget(find.byKey(const ValueKey('no'))), isA<TextButton>());
  });

  testWidgets('aceptar devuelve true', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              answer = await showConfirmDialog(
                context,
                icon: Icons.info_outline,
                title: 't',
                body: 'b',
                confirmLabel: 'Sí',
                cancelLabel: 'No',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();

    expect(answer, isTrue);
  });

  testWidgets('cancelar devuelve false y tocar fuera también', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              answer = await showConfirmDialog(
                context,
                icon: Icons.info_outline,
                title: 't',
                body: 'b',
                confirmLabel: 'Sí',
                cancelLabel: 'No',
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
