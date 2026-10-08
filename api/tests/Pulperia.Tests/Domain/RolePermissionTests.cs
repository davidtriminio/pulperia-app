using Pulperia.Domain.Access;

namespace Pulperia.Tests.Domain;

/// <summary>
/// La matriz de permisos debe coincidir con la del móvil (T025): el servidor es quien
/// decide y el móvil solo la usa para ocultar acciones.
/// </summary>
public class RolePermissionTests
{
    private static readonly HashSet<Permission> EmployeeAllowed =
    [
        Permission.ViewClients,
        Permission.CreateClient,
        Permission.EditClient,
        Permission.RegisterFiado,
        Permission.RegisterPayment,
        Permission.ManageCatalog,
        Permission.ViewSummary,
    ];

    private static readonly HashSet<Permission> EmployeeDenied =
    [
        Permission.AnnulMovement,
        Permission.ArchiveClient,
        Permission.RestoreClient,
        Permission.ManageTeam,
        Permission.ManageBusinessSettings,
    ];

    // ---- Role

    [Fact]
    public void Role_se_identifica_con_ids_estables()
    {
        Assert.Equal(Role.Owner, Roles.FromId("owner"));
        Assert.Equal(Role.Employee, Roles.FromId("employee"));
        Assert.Equal("owner", Role.Owner.Id());
        Assert.Equal("employee", Role.Employee.Id());
    }

    [Theory]
    [InlineData("admin")]
    [InlineData("Owner")]
    [InlineData("")]
    public void Un_id_de_rol_desconocido_lanza_ArgumentException(string id) =>
        Assert.Throws<ArgumentException>(() => Roles.FromId(id));

    [Fact]
    public void TryFromId_devuelve_null_si_no_existe()
    {
        Assert.Equal(Role.Owner, Roles.TryFromId("owner"));
        Assert.Null(Roles.TryFromId("admin"));
        Assert.Null(Roles.TryFromId(null));
    }

    // ---- dueño

    [Fact]
    public void El_dueno_puede_hacerlo_todo()
    {
        foreach (var permission in Enum.GetValues<Permission>())
        {
            Assert.True(RolePermissions.Can(Role.Owner, permission), permission.ToString());
        }
    }

    // ---- empleado (RF-13, RF-21, RF-45, RF-48)

    [Fact]
    public void El_empleado_puede_registrar_crear_editar_administrar_el_catalogo_y_consultar()
    {
        foreach (var permission in EmployeeAllowed)
        {
            Assert.True(RolePermissions.Can(Role.Employee, permission), permission.ToString());
        }
    }

    [Fact]
    public void El_empleado_no_puede_anular_RF45() =>
        Assert.False(RolePermissions.Can(Role.Employee, Permission.AnnulMovement));

    [Fact]
    public void El_empleado_no_puede_archivar_ni_restaurar_clientes_RF21()
    {
        Assert.False(RolePermissions.Can(Role.Employee, Permission.ArchiveClient));
        Assert.False(RolePermissions.Can(Role.Employee, Permission.RestoreClient));
    }

    [Fact]
    public void El_empleado_no_gestiona_el_equipo_ni_los_ajustes_RF13()
    {
        Assert.False(RolePermissions.Can(Role.Employee, Permission.ManageTeam));
        Assert.False(RolePermissions.Can(Role.Employee, Permission.ManageBusinessSettings));
    }

    [Fact]
    public void Lo_permitido_y_lo_denegado_cubren_todos_los_permisos_sin_repetir()
    {
        Assert.Empty(EmployeeAllowed.Intersect(EmployeeDenied));
        Assert.Equal(
            Enum.GetValues<Permission>().ToHashSet(),
            EmployeeAllowed.Union(EmployeeDenied).ToHashSet());
    }

    [Fact]
    public void Exactamente_los_permisos_denegados_son_los_que_se_rechazan()
    {
        var rejected = Enum.GetValues<Permission>()
            .Where(p => !RolePermissions.Can(Role.Employee, p))
            .ToHashSet();

        Assert.Equal(EmployeeDenied, rejected);
    }

    [Fact]
    public void Hay_12_permisos_y_cada_uno_tiene_un_id_estable()
    {
        var ids = Enum.GetValues<Permission>().Select(p => p.Id()).ToList();

        Assert.Equal(12, ids.Count);
        Assert.Equal(ids.Count, ids.Distinct().Count());
        Assert.Equal("annul_movement", Permission.AnnulMovement.Id());
        Assert.Equal("manage_team", Permission.ManageTeam.Id());
    }

    // ---- sin negocio activo

    [Fact]
    public void Un_rol_nulo_no_puede_hacer_nada()
    {
        foreach (var permission in Enum.GetValues<Permission>())
        {
            Assert.False(RolePermissions.CanOrNone(null, permission), permission.ToString());
        }
    }

    [Fact]
    public void Con_rol_CanOrNone_da_lo_mismo_que_Can()
    {
        foreach (var role in Enum.GetValues<Role>())
        {
            foreach (var permission in Enum.GetValues<Permission>())
            {
                Assert.Equal(RolePermissions.Can(role, permission), RolePermissions.CanOrNone(role, permission));
            }
        }
    }
}
