import 'package:flutter/material.dart';

/// Tema de la app: Material 3 con un verde sobrio, pensado para pantallas
/// modestas y uso con una mano en el mostrador.
ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
  visualDensity: VisualDensity.standard,
);
