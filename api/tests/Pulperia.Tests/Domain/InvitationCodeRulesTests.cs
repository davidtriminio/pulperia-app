using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;

namespace Pulperia.Tests.Domain;

/// <summary>T183: códigos de invitación de un solo uso y su canje (RF-92, RF-93, RF-94, D-28).</summary>
public class InvitationCodeRulesTests
{
    private static readonly Guid BusinessId = Guid.CreateVersion7();

    [Fact]
    public void El_alfabeto_no_tiene_caracteres_ambiguos()
    {
        Assert.Equal(31, InvitationCodes.Alphabet.Length);
        Assert.Equal(InvitationCodes.Alphabet.Length, InvitationCodes.Alphabet.Distinct().Count());
        foreach (var ambiguous in "01OIL")
        {
            Assert.DoesNotContain(ambiguous, InvitationCodes.Alphabet);
        }
        Assert.All(InvitationCodes.Alphabet, c => Assert.True(char.IsAsciiLetterUpper(c) || char.IsAsciiDigit(c)));
    }

    [Fact]
    public void Un_codigo_generado_tiene_8_caracteres_del_alfabeto_y_no_se_repite()
    {
        var codes = Enumerable.Range(0, 2_000).Select(_ => InvitationCodes.Generate()).ToList();

        Assert.All(codes, code =>
        {
            Assert.Equal(InvitationCodes.Length, code.Length);
            Assert.All(code, c => Assert.Contains(c, InvitationCodes.Alphabet));
        });
        Assert.Equal(codes.Count, codes.Distinct().Count());
    }

    [Fact]
    public void Se_muestra_como_cuatro_y_cuatro_separados_por_un_guion() =>
        Assert.Equal("ABCD-EFGH", InvitationCodes.Format("ABCDEFGH"));

    [Theory]
    [InlineData("ABCDEFGH", "ABCDEFGH")]
    [InlineData("abcd-efgh", "ABCDEFGH")]
    [InlineData("  AbCd EfGh  ", "ABCDEFGH")]
    [InlineData("ABCD - EFGH", "ABCDEFGH")]
    [InlineData("a2c4-e6g8", "A2C4E6G8")]
    public void Al_canjear_se_ignoran_mayusculas_espacios_y_guiones(string typed, string expected) =>
        Assert.Equal(expected, InvitationCodes.Normalize(typed));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("ABCDEFG")]
    [InlineData("ABCDEFGHJ")]
    [InlineData("ABCD-EFG0")]
    [InlineData("ABCD-EFGO")]
    [InlineData("ABCD-EFG1")]
    [InlineData("ABCD-EFGI")]
    [InlineData("ABCD-EFGL")]
    [InlineData("ABCD-EFG!")]
    [InlineData("ÁBCD-EFGH")]
    public void Un_codigo_mal_formado_no_se_acepta(string? typed) =>
        Assert.Null(InvitationCodes.Normalize(typed));

    [Fact]
    public void Un_codigo_generado_siempre_pasa_la_normalizacion_de_su_forma_mostrada()
    {
        for (var i = 0; i < 500; i++)
        {
            var code = InvitationCodes.Generate();
            Assert.Equal(code, InvitationCodes.Normalize(InvitationCodes.Format(code)));
        }
    }

    // ---- reglas de la invitación

    [Fact]
    public void Una_invitacion_sin_correo_lleva_solo_el_codigo()
    {
        var invitation = InvitationRules.Create(Guid.CreateVersion7(), BusinessId, email: null, code: "ABCDEFGH");

        Assert.Null(invitation.Email);
        Assert.Equal(("ABCDEFGH", InvitationStatus.Pending), (invitation.Code, invitation.Status));
    }

    [Fact]
    public void Una_invitacion_con_correo_lo_normaliza_y_tambien_lleva_codigo()
    {
        var invitation = InvitationRules.Create(Guid.CreateVersion7(), BusinessId, " Beto@Correo.com ", "ABCDEFGH");

        Assert.Equal(("beto@correo.com", "ABCDEFGH"), (invitation.Email, invitation.Code));
    }

    [Fact]
    public void Canjear_el_codigo_de_una_pendiente_la_acepta_y_agrega_un_empleado()
    {
        var invitation = InvitationRules.Create(Guid.CreateVersion7(), BusinessId, null, "ABCDEFGH");

        var result = InvitationRules.AcceptByCode(invitation);

        Assert.True(result.IsValid);
        Assert.Equal(InvitationStatus.Accepted, result.Invitation!.Status);
        Assert.Equal(Role.Employee, result.NewMemberRole);
    }

    [Theory]
    [InlineData(InvitationStatus.Accepted)]
    [InlineData(InvitationStatus.Rejected)]
    [InlineData(InvitationStatus.Cancelled)]
    public void No_se_puede_canjear_el_codigo_de_una_invitacion_resuelta(InvitationStatus status)
    {
        var invitation = new Invitation(Guid.CreateVersion7(), BusinessId, null, status, "ABCDEFGH");

        var result = InvitationRules.AcceptByCode(invitation);

        Assert.False(result.IsValid);
        Assert.Equal(InvitationError.NotPending, result.Error);
    }

    [Fact]
    public void Las_invitaciones_sin_correo_nunca_aparecen_en_las_pendientes_de_un_correo()
    {
        var codeOnly = InvitationRules.Create(Guid.CreateVersion7(), BusinessId, null, "ABCDEFGH");
        var byEmail = InvitationRules.Create(Guid.CreateVersion7(), BusinessId, "beto@correo.com", "JKMNPQRS");

        var pending = InvitationRules.PendingFor("beto@correo.com", [codeOnly, byEmail]);

        Assert.Equal([byEmail], pending);
        Assert.False(InvitationRules.SameEmail(null, "beto@correo.com"));
        Assert.False(InvitationRules.SameEmail("beto@correo.com", null));
    }
}
