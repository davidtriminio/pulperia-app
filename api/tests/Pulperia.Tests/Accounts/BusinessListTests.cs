using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Team;
using Pulperia.Infrastructure.Persistence.Entities;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Accounts;

/// <summary>T065: crear un negocio adicional y listar los negocios del usuario con su rol (RF-5, RF-6, RF-79).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class BusinessListTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Crear_un_negocio_adicional_lo_asigna_al_usuario_como_dueno()
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Service.CreateBusinessAsync(
            account.UserId, "  Segunda sucursal ", AmountMode.Integer, QuantityMode.Integer);

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        var created = result.Value!;
        Assert.Equal(("Segunda sucursal", Role.Owner, AmountMode.Integer, QuantityMode.Integer),
            (created.Name, created.Role, created.AmountMode, created.QuantityMode));
        var business = await kit.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == created.Id);
        Assert.Equal(("Segunda sucursal", Start.UtcDateTime, 0L), (business.Name, business.CreatedAt, business.LastSeq));
        var membership = await kit.Db.Memberships.AsNoTracking().SingleAsync(m => m.BusinessId == created.Id);
        Assert.Equal((account.UserId, Role.Owner, MembershipStatus.Active), (membership.UserId, membership.Role, membership.Status));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Crear_un_negocio_sin_nombre_se_rechaza(string name)
    {
        await using var kit = await CreateAsync(postgres);
        var account = await kit.RegisterAsync();

        var result = await kit.Service.CreateBusinessAsync(account.UserId, name, AmountMode.Integer, QuantityMode.Integer);

        Assert.Equal(["business_name_required"], result.Codes);
        Assert.Single(kit.Db.Businesses);
    }

    [Fact]
    public async Task Un_usuario_con_dos_negocios_los_ve_con_su_rol_en_cada_uno()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        // Ana es empleada en el negocio de Beto (la invitación llega en otra tarea; aquí se siembra).
        kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = ana.UserId, BusinessId = beto.BusinessId, Role = Role.Employee, Status = MembershipStatus.Active,
        });
        await kit.Db.SaveChangesAsync();

        var list = await kit.Service.ListBusinessesAsync(ana.UserId);

        Assert.Equal(
            [("Abarrotes Beto", Role.Employee), ("Pulpería Ana", Role.Owner)],
            list.Select(b => (b.Name, b.Role)));
        Assert.Equal([beto.BusinessId, ana.BusinessId], list.Select(b => b.Id));
    }

    [Fact]
    public async Task El_listado_incluye_los_modos_de_cada_negocio()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration(amountMode: AmountMode.Integer, quantityMode: QuantityMode.Fractional));

        var business = Assert.Single(await kit.Service.ListBusinessesAsync(ana.UserId));

        Assert.Equal((AmountMode.Integer, QuantityMode.Fractional), (business.AmountMode, business.QuantityMode));
    }

    [Fact]
    public async Task El_listado_no_incluye_negocios_ajenos_ni_donde_el_usuario_fue_removido()
    {
        await using var kit = await CreateAsync(postgres);
        var ana = await kit.RegisterAsync(Registration("ana@correo.com", businessName: "Pulpería Ana"));
        var beto = await kit.RegisterAsync(Registration("beto@correo.com", businessName: "Abarrotes Beto"));
        kit.Db.Memberships.Add(new MembershipEntity
        {
            UserId = ana.UserId, BusinessId = beto.BusinessId, Role = Role.Employee,
            Status = MembershipStatus.Removed, RemovedAt = Start.UtcDateTime,
        });
        await kit.Db.SaveChangesAsync();

        var list = await kit.Service.ListBusinessesAsync(ana.UserId);

        Assert.Equal([ana.BusinessId], list.Select(b => b.Id));
    }

    [Fact]
    public async Task Un_usuario_sin_negocios_activos_recibe_una_lista_vacia()
    {
        await using var kit = await CreateAsync(postgres);

        Assert.Empty(await kit.Service.ListBusinessesAsync(Guid.CreateVersion7()));
    }
}
