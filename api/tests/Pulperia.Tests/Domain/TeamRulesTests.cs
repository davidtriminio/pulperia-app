using Pulperia.Domain.Access;
using Pulperia.Domain.Team;

namespace Pulperia.Tests.Domain;

public class TeamRulesTests
{
    private static readonly Guid Ana = Guid.Parse("00000000-0000-7000-8000-000000000001");
    private static readonly Guid Beto = Guid.Parse("00000000-0000-7000-8000-000000000002");
    private static readonly Guid Carla = Guid.Parse("00000000-0000-7000-8000-000000000003");
    private static readonly Guid Desconocido = Guid.Parse("00000000-0000-7000-8000-0000000000ff");

    private static Member Owner(Guid id, MembershipStatus status = MembershipStatus.Active) =>
        new(id, Role.Owner, status);

    private static Member Employee(Guid id, MembershipStatus status = MembershipStatus.Active) =>
        new(id, Role.Employee, status);

    private static Member Find(IReadOnlyList<Member> team, Guid id) => team.Single(m => m.UserId == id);

    // ---- promover a dueño (RF-70)

    [Fact]
    public void Un_empleado_activo_se_promueve_a_dueno()
    {
        var team = new[] { Owner(Ana), Employee(Beto) };

        var result = TeamRules.Promote(team, Beto);

        Assert.True(result.IsValid);
        Assert.Equal(Role.Owner, Find(result.Team!, Beto).Role);
        Assert.Equal(MembershipStatus.Active, Find(result.Team!, Beto).Status);
    }

    [Fact]
    public void El_promovido_recibe_todos_los_permisos_de_dueno()
    {
        var result = TeamRules.Promote([Owner(Ana), Employee(Beto)], Beto);

        var promoted = Find(result.Team!, Beto);
        foreach (var permission in Enum.GetValues<Permission>())
        {
            Assert.True(RolePermissions.Can(promoted.Role, permission), permission.ToString());
        }
    }

    [Fact]
    public void Promover_no_modifica_a_los_demas_ni_la_lista_original()
    {
        var team = new[] { Owner(Ana), Employee(Beto), Employee(Carla) };

        var result = TeamRules.Promote(team, Beto);

        Assert.Equal(Role.Employee, team[1].Role);
        Assert.Equal(Owner(Ana), Find(result.Team!, Ana));
        Assert.Equal(Employee(Carla), Find(result.Team!, Carla));
        Assert.Equal(3, result.Team!.Count);
    }

    [Fact]
    public void No_se_promueve_a_quien_no_es_del_equipo()
    {
        var result = TeamRules.Promote([Owner(Ana)], Desconocido);

        Assert.False(result.IsValid);
        Assert.Equal(TeamError.MemberNotFound, result.Error);
    }

    [Fact]
    public void No_se_promueve_a_un_empleado_removido()
    {
        var result = TeamRules.Promote([Owner(Ana), Employee(Beto, MembershipStatus.Removed)], Beto);

        Assert.Equal(TeamError.MemberNotActive, result.Error);
    }

    [Fact]
    public void Promover_a_alguien_que_ya_es_dueno_se_rechaza()
    {
        var result = TeamRules.Promote([Owner(Ana), Owner(Beto)], Beto);

        Assert.Equal(TeamError.AlreadyOwner, result.Error);
    }

    // ---- quitar a un usuario (RF-11)

    [Fact]
    public void Un_empleado_activo_se_quita_y_queda_removido()
    {
        var result = TeamRules.Remove([Owner(Ana), Employee(Beto)], Beto);

        Assert.True(result.IsValid);
        Assert.Equal(MembershipStatus.Removed, Find(result.Team!, Beto).Status);
        Assert.Equal(MembershipStatus.Active, Find(result.Team!, Ana).Status);
    }

    [Fact]
    public void Quitar_conserva_la_pertenencia_con_estado_removido_y_no_la_borra()
    {
        var result = TeamRules.Remove([Owner(Ana), Employee(Beto)], Beto);

        Assert.Equal(2, result.Team!.Count);
    }

    [Fact]
    public void No_se_quita_a_quien_no_es_del_equipo()
    {
        var result = TeamRules.Remove([Owner(Ana)], Desconocido);

        Assert.Equal(TeamError.MemberNotFound, result.Error);
    }

    [Fact]
    public void Quitar_a_alguien_ya_removido_se_rechaza()
    {
        var result = TeamRules.Remove([Owner(Ana), Employee(Beto, MembershipStatus.Removed)], Beto);

        Assert.Equal(TeamError.MemberNotActive, result.Error);
    }

    // ---- el negocio nunca se queda sin dueño (RF-71)

    [Fact]
    public void No_se_puede_quitar_al_ultimo_dueno()
    {
        var result = TeamRules.Remove([Owner(Ana), Employee(Beto)], Ana);

        Assert.False(result.IsValid);
        Assert.Equal(TeamError.LastOwner, result.Error);
        Assert.Null(result.Team);
    }

    [Fact]
    public void No_se_puede_quitar_al_unico_dueno_aunque_sea_el_unico_miembro()
    {
        Assert.Equal(TeamError.LastOwner, TeamRules.Remove([Owner(Ana)], Ana).Error);
    }

    [Fact]
    public void Un_dueno_removido_no_cuenta_como_dueno_para_el_ultimo()
    {
        // Beto es dueño pero está removido: Ana es la única dueña activa.
        var team = new[] { Owner(Ana), Owner(Beto, MembershipStatus.Removed) };

        Assert.Equal(TeamError.LastOwner, TeamRules.Remove(team, Ana).Error);
    }

    [Fact]
    public void Con_otro_dueno_activo_se_puede_quitar_a_un_dueno()
    {
        var result = TeamRules.Remove([Owner(Ana), Owner(Beto)], Ana);

        Assert.True(result.IsValid);
        Assert.Equal(MembershipStatus.Removed, Find(result.Team!, Ana).Status);
        Assert.Equal(1, TeamRules.ActiveOwnerCount(result.Team!));
    }

    [Fact]
    public void Despues_de_promover_se_puede_quitar_al_dueno_original()
    {
        var promoted = TeamRules.Promote([Owner(Ana), Employee(Beto)], Beto);

        var removed = TeamRules.Remove(promoted.Team!, Ana);

        Assert.True(removed.IsValid);
        Assert.Equal(Role.Owner, Find(removed.Team!, Beto).Role);
    }

    [Fact]
    public void Quitar_la_unica_dueña_se_rechaza_aunque_se_quite_a_si_misma_y_haya_empleados()
    {
        var team = new[] { Owner(Ana), Employee(Beto), Employee(Carla) };

        Assert.Equal(TeamError.LastOwner, TeamRules.Remove(team, Ana).Error);
    }

    // ---- invariante: ninguna secuencia de acciones deja al negocio sin dueño

    [Fact]
    public void Ninguna_secuencia_de_promociones_y_bajas_deja_el_negocio_sin_dueno()
    {
        var random = new Random(2026);
        var ids = Enumerable.Range(1, 6).Select(n => new Guid($"00000000-0000-7000-8000-{n:000000000000}")).ToList();

        for (var run = 0; run < 300; run++)
        {
            IReadOnlyList<Member> team =
            [
                Owner(ids[0]), Employee(ids[1]), Employee(ids[2]),
                Employee(ids[3]), Employee(ids[4]), Employee(ids[5]),
            ];

            for (var step = 0; step < 25; step++)
            {
                var target = ids[random.Next(ids.Count)];
                var result = random.Next(2) == 0 ? TeamRules.Promote(team, target) : TeamRules.Remove(team, target);
                if (result.IsValid)
                {
                    team = result.Team!;
                }

                Assert.True(TeamRules.ActiveOwnerCount(team) >= 1, $"corrida {run}, paso {step}");
            }
        }
    }

    [Fact]
    public void Los_codigos_de_error_son_estables()
    {
        Assert.Equal("team_member_not_found", TeamError.MemberNotFound.Code());
        Assert.Equal("team_member_not_active", TeamError.MemberNotActive.Code());
        Assert.Equal("team_already_owner", TeamError.AlreadyOwner.Code());
        Assert.Equal("team_last_owner", TeamError.LastOwner.Code());
    }

    [Fact]
    public void Contar_dueños_activos_ignora_removidos_y_empleados()
    {
        var team = new[]
        {
            Owner(Ana), Owner(Beto, MembershipStatus.Removed), Employee(Carla),
        };

        Assert.Equal(1, TeamRules.ActiveOwnerCount(team));
    }
}
