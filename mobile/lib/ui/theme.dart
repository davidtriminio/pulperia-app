import 'package:flutter/material.dart';

/// Colores de la app: azul marino con acento turquesa sobre un fondo suave.
abstract final class AppColors {
  static const navy = Color(0xFF0B3C5D);
  static const navyDark = Color(0xFF082B43);
  static const turquoise = Color(0xFF1FB5A8);
  static const background = Color(0xFFF2F7F9);

  /// Relleno y borde de los campos de texto: se ven sobre fondo y sobre
  /// tarjetas blancas.
  static const fieldFill = Color(0xFFE8F0F4);
  static const fieldBorder = Color(0xFF9BB0BE);
  static const ink = Color(0xFF0F2433);

  /// Lo que el cliente debe.
  static const debt = Color(0xFFC62828);
  static const debtDark = Color(0xFF9F1D1D);

  /// Fondo de los avisos de error.
  static const debtSoft = Color(0xFFFDECEC);

  /// Saldo a favor del cliente.
  static const credit = Color(0xFF0B7A70);
}

/// Tema de la app (Material 3): fondo suave, tarjetas blancas muy
/// redondeadas, campos rellenos y botones en píldora con buen tamaño táctil,
/// para usarse con una mano en el mostrador.
ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.navy,
        onPrimary: Colors.white,
        secondary: AppColors.turquoise,
        onSecondary: AppColors.ink,
        error: AppColors.debt,
        onSurface: AppColors.ink,
        surface: Colors.white,
      );

  const radius = BorderRadius.all(Radius.circular(20));
  final inputBorder = OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(16)),
    borderSide: const BorderSide(color: AppColors.fieldBorder),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.fieldFill,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.turquoise, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.debt),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.debt, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.navy,
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.turquoise.withValues(alpha: 0.25),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
