String _comparable(String name) => name.trim().toLowerCase();

/// Indica si [name] coincide con alguno de [existingNames], ignorando
/// mayúsculas y espacios exteriores (RF-17). Solo los espacios exteriores se
/// ignoran: los interiores y las tildes cuentan.
///
/// Es un aviso, no un error: el usuario puede continuar si lo confirma. Un
/// nombre vacío (o solo de espacios) nunca tiene homónimos, porque ya se
/// rechaza aparte (RF-15). Al editar un cliente, [existingNames] no debe
/// incluir el nombre del propio cliente.
bool hasHomonym(String name, Iterable<String> existingNames) {
  final target = _comparable(name);
  if (target.isEmpty) {
    return false;
  }
  return existingNames.any((existing) => _comparable(existing) == target);
}
