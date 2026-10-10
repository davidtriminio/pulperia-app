using System.Net;
using Microsoft.EntityFrameworkCore;
using Pulperia.Domain.Accounts;
using Pulperia.Domain.Admin;
using Pulperia.Domain.Business;
using Pulperia.Tests.Support;
using static Pulperia.Tests.Support.OperationKit;
using static Pulperia.Tests.Support.SyncKit;

namespace Pulperia.Tests.Admin;

/// <summary>Reglas de dominio de la suspensión de una cuenta (RF-99).</summary>
public class AccountSuspensionRulesTests
{
    [Fact]
    public void Suspender_una_cuenta_activa_con_motivo_se_permite()
    {
        Assert.True(AccountSuspensionRules.Suspend(isSuspended: false, "Uso indebido").IsValid);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  ")]
    public void Suspender_sin_motivo_se_rechaza(string? reason)
    {
        var result = AccountSuspensionRules.Suspend(isSuspended: false, reason);

        Assert.Equal(AccountSuspensionError.ReasonRequired, result.Error);
    }

    [Fact]
    public void Suspender_una_ya_suspendida_se_rechaza()
    {
        var result = AccountSuspensionRules.Suspend(isSuspended: true, "otra vez");

        Assert.Equal(AccountSuspensionError.AlreadySuspended, result.Error);
    }

    [Fact]
    public void Reactivar_solo_vale_para_una_cuenta_suspendida()
    {
        Assert.True(AccountSuspensionRules.Reactivate(isSuspended: true).IsValid);
        Assert.Equal(AccountSuspensionError.NotSuspended, AccountSuspensionRules.Reactivate(isSuspended: false).Error);
    }

    [Theory]
    [InlineData(AccountSuspensionError.ReasonRequired, "reason_required")]
    [InlineData(AccountSuspensionError.AlreadySuspended, "account_already_suspended")]
    [InlineData(AccountSuspensionError.NotSuspended, "account_not_suspended")]
    public void Cada_error_tiene_su_codigo_estable(AccountSuspensionError error, string code)
    {
        Assert.Equal(code, error.Code());
    }
}

/// <summary>
/// T191: suspender y reactivar una cuenta con motivo: no inicia sesión, sus sesiones se cierran y
/// sus negocios siguen intactos (RF-99, RF-101, D-29).
/// </summary>
[Collection(PostgresFixture.Collection)]
[Trait("Category", "Integration")]
public class AccountSuspensionTests(PostgresFixture postgres)
{
    private const string Password = "contrasena1";

    private sealed record World(SyncKit Kit, SyncAccount Admin, SyncAccount Ana, SyncAccount Employee);

    private async Task<World> Setup()
    {
        var kit = await StartAsync(postgres);
        var employee = await kit.AddEmployeeAsync("dora@correo.com");
        var admin = await RegisterAsync(kit.Host, "root@plataforma.com");
        await kit.Host.Db.Users.Where(u => u.Id == admin.UserId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.IsSuperAdmin, true));
        return new World(kit, admin, kit.Owner, employee);
    }

    private static Task<HttpResponseMessage> Suspend(World w, Guid user, object? body, string? token = null) =>
        w.Kit.Host.PostAsync($"/api/admin/accounts/{user}/suspend", body, token ?? w.Admin.Token);

    private static Task<HttpResponseMessage> Reactivate(World w, Guid user, string? token = null) =>
        w.Kit.Host.PostAsync($"/api/admin/accounts/{user}/reactivate", new { }, token ?? w.Admin.Token);

    private static async Task<string?> CodeOf(HttpResponseMessage response) =>
        (await ApiTestHost.JsonOf(response)).GetProperty("code").GetString();

    private static Task<HttpResponseMessage> Login(World w, string email, string password = Password) =>
        w.Kit.Host.PostAsync("/api/auth/login", new { email, password });

    // ---- suspender

    [Fact]
    public async Task Suspender_con_motivo_marca_la_cuenta_y_lo_audita()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, w.Employee.UserId, new { reason = "Uso indebido" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal("Uso indebido", body.GetProperty("suspensionReason").GetString());
        Assert.NotEqual(System.Text.Json.JsonValueKind.Null, body.GetProperty("suspendedAt").ValueKind);
        var audit = await w.Kit.Host.Db.AdminAudits.AsNoTracking().SingleAsync();
        Assert.Equal(
            (AdminAction.SuspendAccount, w.Employee.UserId, null, "Uso indebido", "root@plataforma.com"),
            (audit.Action, audit.TargetUserId, audit.TargetBusinessId, audit.Detail, audit.PerformedBy));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("  ")]
    public async Task Suspender_sin_motivo_responde_400_y_no_cambia_nada(string? reason)
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, w.Employee.UserId, new { reason });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("reason_required", await CodeOf(response));
        Assert.Null((await w.Kit.Host.Db.Users.AsNoTracking().SingleAsync(u => u.Id == w.Employee.UserId)).SuspendedAt);
        Assert.Empty(w.Kit.Host.Db.AdminAudits);
    }

    [Fact]
    public async Task Una_cuenta_suspendida_no_inicia_sesion_pero_no_se_le_dice_nada_sin_la_contrasena()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Employee.UserId, new { reason = "Uso indebido" });

        var right = await Login(w, "dora@correo.com");
        var wrong = await Login(w, "dora@correo.com", "equivocada1");

        Assert.Equal(HttpStatusCode.Forbidden, right.StatusCode);
        Assert.Equal("account_suspended", await CodeOf(right));
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal("invalid_credentials", await CodeOf(wrong));
    }

    [Fact]
    public async Task Sus_sesiones_abiertas_dejan_de_servir_y_las_de_otras_cuentas_no()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        var login = await ApiTestHost.JsonOf(await Login(w, "dora@correo.com"));
        var refresh = login.GetProperty("refreshToken").GetString();

        await Suspend(w, w.Employee.UserId, new { reason = "Uso indebido" });

        Assert.Equal(HttpStatusCode.Unauthorized, (await w.Kit.Host.GetAsync("/api/businesses", w.Employee.Token)).StatusCode);
        var renewed = await w.Kit.Host.PostAsync("/api/auth/refresh", new { refreshToken = refresh });
        Assert.Equal(HttpStatusCode.Unauthorized, renewed.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/businesses", w.Ana.Token)).StatusCode);
    }

    [Fact]
    public async Task Sus_negocios_y_pertenencias_siguen_intactos_y_los_demas_miembros_trabajan()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        Guid client = Guid.CreateVersion7();
        await w.Kit.PushOkAsync(w.Ana, SyncOp("client.create", client, ClientPayload("Cliente Uno")));

        await Suspend(w, w.Ana.UserId, new { reason = "Revisión" });

        // La dueña suspendida no entra, pero su negocio sigue activo con sus datos y su empleada trabaja.
        Assert.Equal(BusinessStatus.Active, (await w.Kit.Host.Db.Businesses.AsNoTracking().SingleAsync(b => b.Id == w.Ana.BusinessId)).Status);
        Assert.Equal(2, await w.Kit.Host.Db.Memberships.CountAsync(m => m.BusinessId == w.Ana.BusinessId));
        var list = await w.Kit.Host.GetAsync("/api/clients", w.Employee.Token, w.Ana.BusinessId);
        Assert.Equal(HttpStatusCode.OK, list.StatusCode);
        Assert.Equal(1, (await ApiTestHost.JsonOf(list)).GetArrayLength());
    }

    [Fact]
    public async Task Reactivar_permite_volver_a_entrar_y_lo_audita()
    {
        var w = await Setup();
        await using var _ = w.Kit;
        await Suspend(w, w.Employee.UserId, new { reason = "Uso indebido" });

        var response = await Reactivate(w, w.Employee.UserId);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await ApiTestHost.JsonOf(response);
        Assert.Equal(System.Text.Json.JsonValueKind.Null, body.GetProperty("suspendedAt").ValueKind);
        Assert.Equal(HttpStatusCode.OK, (await Login(w, "dora@correo.com")).StatusCode);
        var audit = await w.Kit.Host.Db.AdminAudits.AsNoTracking().SingleAsync(a => a.Action == AdminAction.ReactivateAccount);
        Assert.Equal((w.Employee.UserId, null), (audit.TargetUserId, audit.Detail));
    }

    // ---- rechazos

    [Fact]
    public async Task Suspender_a_una_suspendida_o_reactivar_a_una_activa_responde_409()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var notSuspended = await Reactivate(w, w.Employee.UserId);
        await Suspend(w, w.Employee.UserId, new { reason = "Uso indebido" });
        var already = await Suspend(w, w.Employee.UserId, new { reason = "Otra vez" });

        Assert.Equal(HttpStatusCode.Conflict, notSuspended.StatusCode);
        Assert.Equal("account_not_suspended", await CodeOf(notSuspended));
        Assert.Equal(HttpStatusCode.Conflict, already.StatusCode);
        Assert.Equal("account_already_suspended", await CodeOf(already));
        Assert.Equal(1, await w.Kit.Host.Db.AdminAudits.CountAsync());
    }

    [Fact]
    public async Task Un_super_administrador_no_puede_suspenderse_a_si_mismo()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, w.Admin.UserId, new { reason = "Prueba" });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Equal("cannot_suspend_self", await CodeOf(response));
        Assert.Equal(HttpStatusCode.OK, (await w.Kit.Host.GetAsync("/api/admin/accounts", w.Admin.Token)).StatusCode);
    }

    [Fact]
    public async Task Una_cuenta_inexistente_responde_404()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var response = await Suspend(w, Guid.CreateVersion7(), new { reason = "x" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("account_not_found", await CodeOf(response));
    }

    [Fact]
    public async Task Un_usuario_normal_no_puede_suspender_ni_reactivar_cuentas()
    {
        var w = await Setup();
        await using var _ = w.Kit;

        var suspend = await Suspend(w, w.Employee.UserId, new { reason = "x" }, w.Ana.Token);
        var reactivate = await Reactivate(w, w.Employee.UserId, w.Ana.Token);

        Assert.Equal(HttpStatusCode.Forbidden, suspend.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, reactivate.StatusCode);
    }
}
