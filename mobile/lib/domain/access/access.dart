/// Rol de un usuario dentro de un negocio. Una misma persona puede tener un
/// rol distinto en cada negocio al que pertenece.
enum Role {
  owner('owner'),
  employee('employee');

  const Role(this.id);

  /// Identificador estable, el mismo que usa la API.
  final String id;

  static Role fromId(String id) => values.firstWhere(
    (r) => r.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'rol desconocido'),
  );
}

/// Acciones sujetas a permiso dentro de un negocio.
enum Permission {
  /// Consultar clientes, sus saldos e historial (RF-48).
  viewClients,

  /// Crear un cliente (RF-48).
  createClient,

  /// Editar un cliente: nombre, avatar, teléfono, dirección y nota (RF-48).
  editClient,

  /// Archivar un cliente (RF-21).
  archiveClient,

  /// Restaurar un cliente archivado (RF-23).
  restoreClient,

  /// Registrar un fiado (RF-48).
  registerFiado,

  /// Registrar un abono (RF-48).
  registerPayment,

  /// Anular un fiado o un abono (RF-45).
  annulMovement,

  /// Crear productos, cambiar su precio y archivarlos (RF-48).
  manageCatalog,

  /// Ver el resumen del negocio (RF-63).
  viewSummary,

  /// Invitar, cancelar invitaciones, promover y quitar usuarios (RF-13).
  manageTeam,

  /// Cambiar el nombre y los modos de montos y cantidades (RF-13).
  manageBusinessSettings,
}

/// Permisos que el empleado no tiene. Todo lo demás lo puede hacer.
const Set<Permission> _ownerOnly = {
  Permission.archiveClient,
  Permission.restoreClient,
  Permission.annulMovement,
  Permission.manageTeam,
  Permission.manageBusinessSettings,
};

/// Indica si [role] tiene [permission]: el dueño puede todo y el empleado
/// todo salvo lo reservado al dueño (RF-13, RF-21, RF-45, RF-48).
bool can(Role role, Permission permission) => switch (role) {
  Role.owner => true,
  Role.employee => !_ownerOnly.contains(permission),
};

/// Como [can], pero un rol nulo (sin negocio activo) no puede hacer nada.
bool canOrNone(Role? role, Permission permission) =>
    role != null && can(role, permission);
