/// Fecha y hora local como `02/10/2026 15:30`. Las fechas se guardan en UTC y
/// solo se convierten a la hora del dispositivo para mostrarlas.
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Fecha local corta como `02/10/2026`.
String formatDate(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
