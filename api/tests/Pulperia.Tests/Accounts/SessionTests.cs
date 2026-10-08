using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Pulperia.Application.Accounts;
using Pulperia.Infrastructure.Accounts;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.AccountKit;

namespace Pulperia.Tests.Accounts;

/// <summary>T064: inicio de sesión, renovación y cierre de sesión contra PostgreSQL real (D-9, D-27).</summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class SessionTests(PostgresFixture postgres)
{
    private static async Task<AuthTokens> Login(AccountKit kit, string email = "ana@correo.com", string password = Password)
    {
        var result = await kit.Service.LoginAsync(email, password);
        return result.IsSuccess ? result.Value! : throw new InvalidOperationException(string.Join(",", result.Codes));
    }

    private static async Task<AccountKit> WithAccount(PostgresFixture postgres)
    {
        var kit = await CreateAsync(postgres);
        await kit.RegisterAsync();
        return kit;
    }

    // ---- inicio de sesión

    [Fact]
    public async Task Iniciar_sesion_entrega_tokens_con_la_caducidad_del_plan()
    {
        await using var kit = await WithAccount(postgres);

        var tokens = await Login(kit);

        Assert.Equal((await kit.Db.Users.SingleAsync()).Id, tokens.UserId);
        Assert.Equal(Start.AddMinutes(15), tokens.AccessExpiresAt);
        Assert.Equal(Start.AddDays(90), tokens.RefreshExpiresAt);
        Assert.NotEqual(tokens.AccessToken, tokens.RefreshToken);
    }

    [Fact]
    public async Task Los_tokens_son_opacos_de_32_bytes_en_base64url_y_distintos_en_cada_sesion()
    {
        await using var kit = await WithAccount(postgres);

        var a = await Login(kit);
        var b = await Login(kit);

        foreach (var token in new[] { a.AccessToken, a.RefreshToken, b.AccessToken, b.RefreshToken })
        {
            Assert.Matches("^[A-Za-z0-9_-]{43}$", token);
        }
        Assert.Equal(4, new[] { a.AccessToken, a.RefreshToken, b.AccessToken, b.RefreshToken }.Distinct().Count());
    }

    [Fact]
    public async Task En_la_base_solo_se_guarda_el_hash_de_los_tokens_nunca_el_token()
    {
        await using var kit = await WithAccount(postgres);

        var tokens = await Login(kit);

        var session = await kit.Db.Sessions.AsNoTracking().SingleAsync();
        Assert.NotEqual(tokens.AccessToken, session.AccessTokenHash);
        Assert.NotEqual(tokens.RefreshToken, session.RefreshTokenHash);
        Assert.Equal(Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(tokens.AccessToken))), session.AccessTokenHash);
        Assert.Equal(Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(tokens.RefreshToken))), session.RefreshTokenHash);
    }

    [Theory]
    [InlineData("ana@correo.com", "otra-contrasena")]
    [InlineData("nadie@correo.com", "contrasena1")]
    [InlineData("", "")]
    public async Task Credenciales_erroneas_dan_el_mismo_rechazo_sin_distinguir_correo_de_contrasena(string email, string password)
    {
        await using var kit = await WithAccount(postgres);

        var result = await kit.Service.LoginAsync(email, password);

        Assert.False(result.IsSuccess);
        Assert.Equal(["invalid_credentials"], result.Codes);
        Assert.Empty(kit.Db.Sessions);
    }

    [Fact]
    public async Task El_correo_no_distingue_mayusculas_ni_espacios_al_iniciar_sesion()
    {
        await using var kit = await WithAccount(postgres);

        var result = await kit.Service.LoginAsync("  ANA@Correo.com ", Password);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public async Task Un_hash_con_menos_iteraciones_se_renueva_al_iniciar_sesion()
    {
        await using var kit = await WithAccount(postgres);
        var before = (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash;
        var stronger = new AccountService(new EfAccountStore(kit.Db), new PasswordHasher(iterations: 2_000), kit.Clock);

        Assert.True((await stronger.LoginAsync("ana@correo.com", Password)).IsSuccess);

        var after = (await kit.Db.Users.AsNoTracking().SingleAsync()).PasswordHash;
        Assert.NotEqual(before, after);
        Assert.StartsWith("pbkdf2-sha256$2000$", after);
        Assert.True(new PasswordHasher(iterations: 2_000).Verify(after, Password).IsValid);
    }

    // ---- caducidad del acceso

    [Fact]
    public async Task El_token_de_acceso_sirve_hasta_que_caduca()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);

        Assert.NotNull(await kit.Service.AuthenticateAsync(tokens.AccessToken));
        kit.Clock.Advance(TimeSpan.FromMinutes(14) + TimeSpan.FromSeconds(59));
        Assert.NotNull(await kit.Service.AuthenticateAsync(tokens.AccessToken));
        kit.Clock.Advance(TimeSpan.FromSeconds(2));
        Assert.Null(await kit.Service.AuthenticateAsync(tokens.AccessToken));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("no-es-un-token")]
    public async Task Un_token_desconocido_o_vacio_no_autentica(string token)
    {
        await using var kit = await WithAccount(postgres);

        Assert.Null(await kit.Service.AuthenticateAsync(token));
    }

    [Fact]
    public async Task El_token_de_renovacion_no_sirve_como_token_de_acceso()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);

        Assert.Null(await kit.Service.AuthenticateAsync(tokens.RefreshToken));
    }

    // ---- renovación

    [Fact]
    public async Task Renovar_entrega_tokens_nuevos_y_el_de_renovacion_anterior_deja_de_servir()
    {
        await using var kit = await WithAccount(postgres);
        var first = await Login(kit);
        kit.Clock.Advance(TimeSpan.FromMinutes(20));

        var renewed = await kit.Service.RefreshAsync(first.RefreshToken);

        Assert.True(renewed.IsSuccess, string.Join(",", renewed.Codes));
        var second = renewed.Value!;
        Assert.Equal(first.UserId, second.UserId);
        Assert.Equal(Start.AddMinutes(35), second.AccessExpiresAt);
        Assert.Equal(Start.AddMinutes(20).AddDays(90), second.RefreshExpiresAt);
        Assert.NotNull(await kit.Service.AuthenticateAsync(second.AccessToken));
        Assert.Null(await kit.Service.AuthenticateAsync(first.AccessToken));
        var reused = await kit.Service.RefreshAsync(first.RefreshToken);
        Assert.Equal(["invalid_refresh_token"], reused.Codes);
        Assert.Single(kit.Db.Sessions);
    }

    [Fact]
    public async Task Renovar_funciona_con_el_acceso_ya_caducado_y_dentro_de_los_90_dias()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);
        kit.Clock.Advance(TimeSpan.FromDays(89));

        Assert.Null(await kit.Service.AuthenticateAsync(tokens.AccessToken));
        Assert.True((await kit.Service.RefreshAsync(tokens.RefreshToken)).IsSuccess);
    }

    [Fact]
    public async Task Un_token_de_renovacion_caducado_o_desconocido_se_rechaza()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);

        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync("desconocido")).Codes);
        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync("")).Codes);
        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync(tokens.AccessToken)).Codes);
        kit.Clock.Advance(TimeSpan.FromDays(90) + TimeSpan.FromSeconds(1));
        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync(tokens.RefreshToken)).Codes);
    }

    [Fact]
    public async Task Dos_renovaciones_a_la_vez_con_el_mismo_token_solo_dejan_pasar_una()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);
        var connectionString = kit.Db.Database.GetConnectionString()!;

        async Task<bool> Renew()
        {
            await using var db = PostgresFixture.NewContext(connectionString);
            var service = new AccountService(new EfAccountStore(db), kit.Hasher, kit.Clock);
            return (await service.RefreshAsync(tokens.RefreshToken)).IsSuccess;
        }

        var results = await Task.WhenAll(Renew(), Renew());

        Assert.Equal(1, results.Count(ok => ok));
    }

    // ---- cierre de sesión

    [Fact]
    public async Task Tras_cerrar_sesion_ni_el_acceso_ni_la_renovacion_sirven()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);

        await kit.Service.LogoutAsync(tokens.AccessToken);

        Assert.Null(await kit.Service.AuthenticateAsync(tokens.AccessToken));
        Assert.Equal(["invalid_refresh_token"], (await kit.Service.RefreshAsync(tokens.RefreshToken)).Codes);
        Assert.Equal(Start.UtcDateTime, (await kit.Db.Sessions.AsNoTracking().SingleAsync()).RevokedAt);
    }

    [Fact]
    public async Task Cerrar_sesion_dos_veces_o_con_un_token_desconocido_no_falla()
    {
        await using var kit = await WithAccount(postgres);
        var tokens = await Login(kit);

        await kit.Service.LogoutAsync(tokens.AccessToken);
        kit.Clock.Advance(TimeSpan.FromMinutes(1));
        await kit.Service.LogoutAsync(tokens.AccessToken);
        await kit.Service.LogoutAsync("desconocido");

        Assert.Equal(Start.UtcDateTime, (await kit.Db.Sessions.AsNoTracking().SingleAsync()).RevokedAt);
    }

    [Fact]
    public async Task Cerrar_una_sesion_no_toca_las_de_otros_dispositivos()
    {
        await using var kit = await WithAccount(postgres);
        var phone = await Login(kit);
        var web = await Login(kit);

        await kit.Service.LogoutAsync(phone.AccessToken);

        Assert.Null(await kit.Service.AuthenticateAsync(phone.AccessToken));
        Assert.NotNull(await kit.Service.AuthenticateAsync(web.AccessToken));
    }
}
