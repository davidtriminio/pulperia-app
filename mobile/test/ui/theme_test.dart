import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/ui/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  inputVisibilityTests();
  final theme = buildTheme();
  final scheme = theme.colorScheme;

  test('usa la paleta azul marino con acento turquesa', () {
    expect(scheme.primary, AppColors.navy);
    expect(scheme.secondary, AppColors.turquoise);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('la deuda y el saldo a favor son colores distintos', () {
    expect(AppColors.debt, isNot(AppColors.credit));
    expect(scheme.error, AppColors.debt);
  });

  group('contraste legible (WCAG AA, 4.5:1)', () {
    test('texto sobre el color primario', () {
      expect(_contrast(scheme.primary, scheme.onPrimary), greaterThan(4.5));
    });
    test('deuda sobre una tarjeta blanca', () {
      expect(_contrast(AppColors.debt, Colors.white), greaterThan(4.5));
    });
    test('saldo a favor sobre una tarjeta blanca', () {
      expect(_contrast(AppColors.credit, Colors.white), greaterThan(4.5));
    });
    test('texto principal sobre el fondo', () {
      expect(
        _contrast(scheme.onSurface, theme.scaffoldBackgroundColor),
        greaterThan(7),
      );
    });
  });

  test('las tarjetas son blancas y muy redondeadas', () {
    final shape = theme.cardTheme.shape as RoundedRectangleBorder;
    final radius = (shape.borderRadius as BorderRadius).topLeft.x;
    expect(radius, greaterThanOrEqualTo(16));
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, 0);
  });

  test('los campos de texto son rellenos y redondeados', () {
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.border, isA<OutlineInputBorder>());
  });

  test('los botones tienen forma de píldora y buen alto táctil', () {
    final style = theme.filledButtonTheme.style!;
    expect(style.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(48));
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
  });

  test('la barra superior es plana y sin tinte', () {
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.appBarTheme.backgroundColor, AppColors.background);
  });
}

void inputVisibilityTests() {
  final theme = buildTheme();
  const white = Colors.white;

  group('los campos de texto se distinguen de la tarjeta blanca', () {
    test('el relleno no es blanco', () {
      expect(theme.inputDecorationTheme.fillColor, isNot(white));
      expect(
        _contrast(theme.inputDecorationTheme.fillColor!, white),
        greaterThan(1.1),
      );
    });

    test('tienen un borde visible sobre blanco', () {
      final border =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(border.borderSide.style, BorderStyle.solid);
      expect(border.borderSide.width, greaterThanOrEqualTo(1));
      expect(_contrast(border.borderSide.color, white), greaterThan(1.5));
    });

    test('el campo enfocado resalta con el acento', () {
      final focused =
          theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focused.borderSide.color, AppColors.turquoise);
      expect(focused.borderSide.width, greaterThanOrEqualTo(2));
    });
  });
}
