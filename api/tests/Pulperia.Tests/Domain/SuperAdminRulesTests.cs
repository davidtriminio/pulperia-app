using Pulperia.Domain.Admin;

namespace Pulperia.Tests.Domain;

/// <summary>T186: marcar y retirar la marca de super administrador (RF-95).</summary>
public class SuperAdminRulesTests
{
    [Fact]
    public void Marcar_a_quien_no_lo_es_se_permite()
    {
        Assert.True(SuperAdminRules.Grant(isSuperAdmin: false).IsValid);
    }

    [Fact]
    public void Marcar_a_quien_ya_lo_es_se_rechaza()
    {
        var result = SuperAdminRules.Grant(isSuperAdmin: true);

        Assert.Equal(SuperAdminError.AlreadySuperAdmin, result.Error);
    }

    [Fact]
    public void Retirar_la_marca_a_uno_de_varios_se_permite()
    {
        Assert.True(SuperAdminRules.Revoke(isSuperAdmin: true, superAdminCount: 2).IsValid);
    }

    [Fact]
    public void Retirar_la_marca_al_ultimo_se_rechaza()
    {
        var result = SuperAdminRules.Revoke(isSuperAdmin: true, superAdminCount: 1);

        Assert.Equal(SuperAdminError.LastSuperAdmin, result.Error);
    }

    [Fact]
    public void Retirar_la_marca_a_quien_no_la_tiene_se_rechaza()
    {
        var result = SuperAdminRules.Revoke(isSuperAdmin: false, superAdminCount: 3);

        Assert.Equal(SuperAdminError.NotSuperAdmin, result.Error);
    }

    [Theory]
    [InlineData(SuperAdminError.AlreadySuperAdmin, "already_super_admin")]
    [InlineData(SuperAdminError.NotSuperAdmin, "not_super_admin")]
    [InlineData(SuperAdminError.LastSuperAdmin, "last_super_admin")]
    public void Cada_error_tiene_su_codigo_estable(SuperAdminError error, string code)
    {
        Assert.Equal(code, error.Code());
    }

    [Fact]
    public void Las_acciones_de_administracion_tienen_identificador_estable_y_ida_y_vuelta()
    {
        var ids = new Dictionary<AdminAction, string>
        {
            [AdminAction.ResetPassword] = "reset_password",
            [AdminAction.GrantSuperAdmin] = "grant_superadmin",
            [AdminAction.RevokeSuperAdmin] = "revoke_superadmin",
            [AdminAction.SuspendBusiness] = "suspend_business",
            [AdminAction.ReactivateBusiness] = "reactivate_business",
            [AdminAction.ActivateBusiness] = "activate_business",
            [AdminAction.SuspendAccount] = "suspend_account",
            [AdminAction.ReactivateAccount] = "reactivate_account",
        };

        Assert.Equal(Enum.GetValues<AdminAction>().Length, ids.Count);
        foreach (var (action, id) in ids)
        {
            Assert.Equal(id, action.Id());
            Assert.Equal(action, AdminActions.FromId(id));
        }
    }
}
