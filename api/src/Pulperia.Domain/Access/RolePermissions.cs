namespace Pulperia.Domain.Access;

/// <summary>
/// Rol de un usuario dentro de un negocio. Una misma persona puede tener un rol distinto
/// en cada negocio al que pertenece.
/// </summary>
public enum Role
{
    Owner,
    Employee,
}

public static class Roles
{
    /// <summary>Identificador estable, el mismo que usa el móvil y la API.</summary>
    public static string Id(this Role role) => role switch
    {
        Role.Owner => "owner",
        Role.Employee => "employee",
        _ => throw new ArgumentOutOfRangeException(nameof(role)),
    };

    public static Role? TryFromId(string? id) => id switch
    {
        "owner" => Role.Owner,
        "employee" => Role.Employee,
        _ => null,
    };

    public static Role FromId(string id) =>
        TryFromId(id) ?? throw new ArgumentException($"Rol desconocido: {id}", nameof(id));
}

/// <summary>Acciones sujetas a permiso dentro de un negocio.</summary>
public enum Permission
{
    /// <summary>Consultar clientes, sus saldos e historial (RF-48).</summary>
    ViewClients,

    /// <summary>Crear un cliente (RF-48).</summary>
    CreateClient,

    /// <summary>Editar un cliente: nombre, avatar, teléfono, dirección y nota (RF-48).</summary>
    EditClient,

    /// <summary>Archivar un cliente (RF-21).</summary>
    ArchiveClient,

    /// <summary>Restaurar un cliente archivado (RF-23).</summary>
    RestoreClient,

    /// <summary>Registrar un fiado (RF-48).</summary>
    RegisterFiado,

    /// <summary>Registrar un abono (RF-48).</summary>
    RegisterPayment,

    /// <summary>Anular un fiado o un abono (RF-45).</summary>
    AnnulMovement,

    /// <summary>Crear productos, cambiar su precio y archivarlos (RF-48).</summary>
    ManageCatalog,

    /// <summary>Ver el resumen del negocio (RF-63).</summary>
    ViewSummary,

    /// <summary>Invitar, cancelar invitaciones, promover y quitar usuarios (RF-13).</summary>
    ManageTeam,

    /// <summary>Cambiar el nombre y los modos de montos y cantidades (RF-13).</summary>
    ManageBusinessSettings,
}

public static class RolePermissions
{
    /// <summary>Permisos que el empleado no tiene. Todo lo demás lo puede hacer.</summary>
    private static readonly HashSet<Permission> OwnerOnly =
    [
        Permission.ArchiveClient,
        Permission.RestoreClient,
        Permission.AnnulMovement,
        Permission.ManageTeam,
        Permission.ManageBusinessSettings,
    ];

    /// <summary>Identificador estable de un permiso, en minúsculas con guion bajo.</summary>
    public static string Id(this Permission permission) => permission switch
    {
        Permission.ViewClients => "view_clients",
        Permission.CreateClient => "create_client",
        Permission.EditClient => "edit_client",
        Permission.ArchiveClient => "archive_client",
        Permission.RestoreClient => "restore_client",
        Permission.RegisterFiado => "register_fiado",
        Permission.RegisterPayment => "register_payment",
        Permission.AnnulMovement => "annul_movement",
        Permission.ManageCatalog => "manage_catalog",
        Permission.ViewSummary => "view_summary",
        Permission.ManageTeam => "manage_team",
        Permission.ManageBusinessSettings => "manage_business_settings",
        _ => throw new ArgumentOutOfRangeException(nameof(permission)),
    };

    /// <summary>
    /// Indica si <paramref name="role"/> tiene <paramref name="permission"/>: el dueño puede
    /// todo y el empleado todo salvo lo reservado al dueño (RF-13, RF-21, RF-45, RF-48).
    /// </summary>
    public static bool Can(Role role, Permission permission) => role switch
    {
        Role.Owner => true,
        Role.Employee => !OwnerOnly.Contains(permission),
        _ => false,
    };

    /// <summary>Como <see cref="Can"/>, pero un rol nulo (sin pertenencia activa) no puede hacer nada.</summary>
    public static bool CanOrNone(Role? role, Permission permission) =>
        role is not null && Can(role.Value, permission);
}
