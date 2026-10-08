using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Team;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Accounts;

/// <summary>T063: registro con correo, contraseña y nombre de negocio contra PostgreSQL real.</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class RegistrationTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Registrarse_crea_el_usuario_el_negocio_y_la_pertenencia_de_dueno()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Service.RegisterAsync(
            Registration("  Ana@Correo.com ", businessName: "  Pulpería Ana  ",
                amountMode: AmountMode.Integer, quantityMode: QuantityMode.Integer));

        Assert.True(result.IsSuccess, string.Join(",", result.Codes));
        var user = await kit.Db.Users.AsNoTracking().SingleAsync();
        Assert.Equal(("ana@correo.com", Start.UtcDateTime), (user.Email, user.CreatedAt));
        Assert.Equal(result.Value!.UserId, user.Id);
        var business = await kit.Db.Businesses.AsNoTracking().SingleAsync();
        Assert.Equal(result.Value.BusinessId, business.Id);
        Assert.Equal(("Pulpería Ana", AmountMode.Integer, QuantityMode.Integer, 0L),
            (business.Name, business.AmountMode, business.QuantityMode, business.LastSeq));
        var membership = await kit.Db.Memberships.AsNoTracking().SingleAsync();
        Assert.Equal((user.Id, business.Id, Role.Owner, MembershipStatus.Active),
            (membership.UserId, membership.BusinessId, membership.Role, membership.Status));
    }

    [Fact]
    public async Task La_contrasena_se_guarda_solo_como_hash_que_verifica()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();

        var stored = (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash;

        Assert.DoesNotContain(Password, stored);
        Assert.True(kit.Hasher.Verify(stored, Password).IsValid);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Sin_nombre_de_negocio_se_rechaza_y_no_se_crea_nada(string name)
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Service.RegisterAsync(Registration(businessName: name));

        Assert.False(result.IsSuccess);
        Assert.Equal("business_name_required", result.Codes[0]);
        Assert.Empty(kit.Db.Users);
        Assert.Empty(kit.Db.Businesses);
        Assert.Empty(kit.Db.Memberships);
    }

    [Fact]
    public async Task Correo_o_contrasena_invalidos_se_rechazan_con_todos_sus_codigos()
    {
        await using var kit = await CreateAsync(postgres);

        var result = await kit.Service.RegisterAsync(Registration("ana", "corta", ""));

        Assert.Equal(["email_invalid", "password_too_short", "business_name_required"], result.Codes);
        Assert.Empty(kit.Db.Users);
    }

    [Fact]
    public async Task Un_correo_ya_registrado_se_rechaza_sin_distinguir_mayusculas()
    {
        await using var kit = await CreateAsync(postgres);
        await kit.RegisterAsync(Registration("ana@correo.com"));

        var again = await kit.Service.RegisterAsync(Registration(" ANA@correo.com ", businessName: "Otra"));

        Assert.False(again.IsSuccess);
        Assert.Equal(["email_taken"], again.Codes);
        Assert.Single(kit.Db.Users);
        Assert.Single(kit.Db.Businesses);
    }

    [Fact]
    public async Task Dos_registros_a_la_vez_con_el_mismo_correo_dejan_una_sola_cuenta()
    {
        await using var kit = await CreateAsync(postgres);
        var connectionString = kit.Db.Database.GetConnectionString()!;

        async Task<bool> Register()
        {
            await using var db = PostgresFixture.NewContext(connectionString);
            var service = new Pulperia.Application.Accounts.AccountService(
                new Pulperia.Infrastructure.Accounts.EfAccountStore(db), kit.Hasher, kit.Clock);
            return (await service.RegisterAsync(Registration())).IsSuccess;
        }

        var results = await Task.WhenAll(Register(), Register());

        Assert.Equal(1, results.Count(ok => ok));
        Assert.Single(kit.Db.Users);
        Assert.Single(kit.Db.Businesses);
    }

    [Fact]
    public async Task Cada_cuenta_tiene_su_propio_negocio_aunque_el_nombre_se_repita()
    {
        await using var kit = await CreateAsync(postgres);

        var a = await kit.RegisterAsync(Registration("a@correo.com"));
        var b = await kit.RegisterAsync(Registration("b@correo.com"));

        Assert.NotEqual(a.BusinessId, b.BusinessId);
        Assert.Equal(2, await kit.Db.Businesses.CountAsync());
    }
}
