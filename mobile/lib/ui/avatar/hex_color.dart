import 'package:flutter/painting.dart';

/// Convierte un color `#RRGGBB` de la paleta en un [Color] opaco.
Color hexColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
