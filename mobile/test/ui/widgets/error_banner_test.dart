import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/ui/theme.dart';
import 'package:pulperia_mobile/ui/widgets/error_banner.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('el aviso muestra icono y texto en negrita', (tester) async {
    await tester.pumpWidget(_host(const ErrorBanner('Algo salió mal')));

    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    final text = tester.widget<Text>(find.text('Algo salió mal'));
    expect(text.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('varios mensajes van en una sola tarjeta', (tester) async {
    await tester.pumpWidget(_host(const ErrorBanner.all(['Uno', 'Dos'])));

    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('el error de un campo lleva icono y borde rojo', (tester) async {
    await tester.pumpWidget(
      _host(
        TextField(
          decoration: InputDecoration(
            labelText: 'Nombre',
            error: fieldError('El nombre es obligatorio'),
          ),
        ),
      ),
    );

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  test('sin texto no hay error de campo', () {
    expect(fieldError(null), isNull);
  });
}
