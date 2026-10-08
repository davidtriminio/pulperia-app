using Pulperia.Domain.Accounts;

namespace Pulperia.Tests.Domain;

/// <summary>T063: reglas de cuenta y de nombre de negocio (RF-1, RF-2, RF-78, D-27).</summary>
public class AccountRulesTests
{
    [Theory]
    [InlineData("  Ana@Correo.COM ", "ana@correo.com")]
    [InlineData("dueno@pulperia.hn", "dueno@pulperia.hn")]
    public void El_correo_se_recorta_y_se_pasa_a_minusculas(string raw, string expected) =>
        Assert.Equal(expected, AccountRules.NormalizeEmail(raw));

    [Theory]
    [InlineData("ana@correo.com", true)]
    [InlineData("a@b", true)]
    [InlineData("", false)]
    [InlineData("ana", false)]
    [InlineData("@correo.com", false)]
    [InlineData("ana@", false)]
    [InlineData("a na@correo.com", false)]
    [InlineData("ana@@correo.com", false)]
    public void El_correo_debe_tener_forma_de_direccion(string email, bool valid) =>
        Assert.Equal(valid, AccountRules.IsValidEmail(AccountRules.NormalizeEmail(email)));

    [Theory]
    [InlineData(7, "password_too_short")]
    [InlineData(0, "password_too_short")]
    [InlineData(129, "password_too_long")]
    public void La_contrasena_fuera_de_8_a_128_caracteres_se_rechaza(int length, string code) =>
        Assert.Equal(code, AccountRules.PasswordError(new string('x', length)));

    [Theory]
    [InlineData(8)]
    [InlineData(128)]
    public void La_contrasena_de_8_a_128_caracteres_se_acepta(int length) =>
        Assert.Null(AccountRules.PasswordError(new string('x', length)));

    [Fact]
    public void Una_contrasena_nula_cuenta_como_demasiado_corta() =>
        Assert.Equal("password_too_short", AccountRules.PasswordError(null));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void El_nombre_del_negocio_es_obligatorio(string? name) =>
        Assert.Equal("business_name_required", AccountRules.BusinessNameError(name));

    [Fact]
    public void Un_nombre_de_negocio_con_texto_es_valido() =>
        Assert.Null(AccountRules.BusinessNameError("  Pulpería Ana "));

    [Fact]
    public void El_registro_reporta_todos_los_problemas_en_orden()
    {
        var codes = AccountRules.ValidateRegistration("ana", "corta", " ");

        Assert.Equal(["email_invalid", "password_too_short", "business_name_required"], codes);
    }

    [Fact]
    public void Un_registro_correcto_no_tiene_problemas() =>
        Assert.Empty(AccountRules.ValidateRegistration("ana@correo.com", "contrasena1", "Pulpería Ana"));
}
