using Pulperia.Domain.Access;
using Pulperia.Domain.Invitations;

namespace Pulperia.Tests.Domain;

public class InvitationRulesTests
{
    private static readonly Guid InvitationId = Guid.Parse("00000000-0000-7000-8000-0000000000a1");
    private static readonly Guid BusinessId = Guid.Parse("00000000-0000-7000-8000-0000000000b1");
    private const string Email = "beto@correo.com";

    private static Invitation WithStatus(InvitationStatus status, string email = Email) =>
        new(InvitationId, BusinessId, email, status);

    private static IEnumerable<InvitationStatus> NotPending =>
        Enum.GetValues<InvitationStatus>().Where(s => s != InvitationStatus.Pending);

    // ---- crear (RF-10)

    [Fact]
    public void Una_invitacion_nueva_queda_pendiente_y_asociada_al_correo()
    {
        var invitation = InvitationRules.Create(InvitationId, BusinessId, Email);

        Assert.Equal(InvitationStatus.Pending, invitation.Status);
        Assert.Equal(Email, invitation.Email);
        Assert.Equal(BusinessId, invitation.BusinessId);
        Assert.Equal(InvitationId, invitation.Id);
    }

    [Fact]
    public void El_correo_se_guarda_sin_espacios_exteriores_y_en_minusculas()
    {
        var invitation = InvitationRules.Create(InvitationId, BusinessId, "  Beto@Correo.COM ");

        Assert.Equal("beto@correo.com", invitation.Email);
    }

    [Theory]
    [InlineData("Beto@Correo.com", "beto@correo.com", true)]
    [InlineData("  beto@correo.com  ", "beto@correo.com", true)]
    [InlineData("BETO@CORREO.COM", "beto@correo.com", true)]
    [InlineData("beto@correo.com", "ana@correo.com", false)]
    [InlineData("beto@correo.com", "beto@correo.co", false)]
    [InlineData("beto@correo.com", "", false)]
    public void Los_correos_se_comparan_sin_mayusculas_ni_espacios_exteriores(string a, string b, bool same) =>
        Assert.Equal(same, InvitationRules.SameEmail(a, b));

    // ---- aceptar (RF-67, RF-68)

    [Fact]
    public void La_persona_invitada_acepta_una_invitacion_pendiente_y_entra_como_empleado()
    {
        var result = InvitationRules.Accept(WithStatus(InvitationStatus.Pending), Email);

        Assert.True(result.IsValid);
        Assert.Equal(InvitationStatus.Accepted, result.Invitation!.Status);
        Assert.Equal(Role.Employee, result.NewMemberRole);
    }

    [Fact]
    public void Aceptar_funciona_aunque_el_correo_llegue_con_otras_mayusculas_o_espacios()
    {
        var result = InvitationRules.Accept(WithStatus(InvitationStatus.Pending), "  BETO@correo.com ");

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Aceptar_siempre_da_rol_de_empleado_nunca_de_dueno()
    {
        // RF-68: sin importar si ya pertenece a otros negocios ni con qué rol.
        var result = InvitationRules.Accept(WithStatus(InvitationStatus.Pending), Email);

        Assert.Equal(Role.Employee, result.NewMemberRole);
        Assert.NotEqual(Role.Owner, result.NewMemberRole);
    }

    [Fact]
    public void Otra_persona_no_puede_aceptar_una_invitacion_ajena()
    {
        var invitation = WithStatus(InvitationStatus.Pending);

        var result = InvitationRules.Accept(invitation, "ana@correo.com");

        Assert.False(result.IsValid);
        Assert.Equal(InvitationError.NotInvitee, result.Error);
        Assert.Null(result.NewMemberRole);
    }

    [Theory]
    [InlineData(InvitationStatus.Accepted)]
    [InlineData(InvitationStatus.Rejected)]
    [InlineData(InvitationStatus.Cancelled)]
    public void Solo_se_acepta_una_invitacion_pendiente(InvitationStatus status)
    {
        var result = InvitationRules.Accept(WithStatus(status), Email);

        Assert.Equal(InvitationError.NotPending, result.Error);
        Assert.Null(result.NewMemberRole);
    }

    [Fact]
    public void Una_invitacion_cancelada_no_se_puede_aceptar_RF69()
    {
        var cancelled = InvitationRules.Cancel(WithStatus(InvitationStatus.Pending)).Invitation!;

        var result = InvitationRules.Accept(cancelled, Email);

        Assert.False(result.IsValid);
        Assert.Equal(InvitationError.NotPending, result.Error);
    }

    // ---- rechazar (RF-67)

    [Fact]
    public void La_persona_invitada_rechaza_una_invitacion_pendiente()
    {
        var result = InvitationRules.Reject(WithStatus(InvitationStatus.Pending), Email);

        Assert.True(result.IsValid);
        Assert.Equal(InvitationStatus.Rejected, result.Invitation!.Status);
        Assert.Null(result.NewMemberRole);
    }

    [Fact]
    public void Otra_persona_no_puede_rechazar_una_invitacion_ajena()
    {
        var result = InvitationRules.Reject(WithStatus(InvitationStatus.Pending), "ana@correo.com");

        Assert.Equal(InvitationError.NotInvitee, result.Error);
    }

    [Theory]
    [InlineData(InvitationStatus.Accepted)]
    [InlineData(InvitationStatus.Rejected)]
    [InlineData(InvitationStatus.Cancelled)]
    public void Solo_se_rechaza_una_invitacion_pendiente(InvitationStatus status) =>
        Assert.Equal(InvitationError.NotPending, InvitationRules.Reject(WithStatus(status), Email).Error);

    // ---- cancelar (RF-69)

    [Fact]
    public void Un_dueno_cancela_una_invitacion_pendiente()
    {
        var result = InvitationRules.Cancel(WithStatus(InvitationStatus.Pending));

        Assert.True(result.IsValid);
        Assert.Equal(InvitationStatus.Cancelled, result.Invitation!.Status);
    }

    [Theory]
    [InlineData(InvitationStatus.Accepted)]
    [InlineData(InvitationStatus.Rejected)]
    [InlineData(InvitationStatus.Cancelled)]
    public void Solo_se_cancela_una_invitacion_pendiente(InvitationStatus status) =>
        Assert.Equal(InvitationError.NotPending, InvitationRules.Cancel(WithStatus(status)).Error);

    // ---- no filtrar el estado a quien no es el invitado

    [Theory]
    [InlineData(InvitationStatus.Pending)]
    [InlineData(InvitationStatus.Accepted)]
    [InlineData(InvitationStatus.Cancelled)]
    public void Un_extrano_siempre_recibe_NotInvitee_y_no_el_estado(InvitationStatus status)
    {
        var accept = InvitationRules.Accept(WithStatus(status), "otra@correo.com");
        var reject = InvitationRules.Reject(WithStatus(status), "otra@correo.com");

        Assert.Equal(InvitationError.NotInvitee, accept.Error);
        Assert.Equal(InvitationError.NotInvitee, reject.Error);
    }

    // ---- mostrar al iniciar sesión (RF-67)

    [Fact]
    public void Al_iniciar_sesion_solo_se_muestran_las_pendientes_de_su_correo()
    {
        var mine = new Invitation(Guid.NewGuid(), BusinessId, Email, InvitationStatus.Pending);
        var mineOtherCase = new Invitation(Guid.NewGuid(), Guid.NewGuid(), "BETO@correo.com", InvitationStatus.Pending);
        var accepted = new Invitation(Guid.NewGuid(), BusinessId, Email, InvitationStatus.Accepted);
        var cancelled = new Invitation(Guid.NewGuid(), BusinessId, Email, InvitationStatus.Cancelled);
        var rejected = new Invitation(Guid.NewGuid(), BusinessId, Email, InvitationStatus.Rejected);
        var others = new Invitation(Guid.NewGuid(), BusinessId, "ana@correo.com", InvitationStatus.Pending);

        var visible = InvitationRules.PendingFor(Email, [mine, mineOtherCase, accepted, cancelled, rejected, others]);

        Assert.Equal([mine, mineOtherCase], visible);
    }

    // ---- tabla de transiciones

    [Fact]
    public void Desde_un_estado_final_no_hay_ninguna_transicion()
    {
        foreach (var status in NotPending)
        {
            var invitation = WithStatus(status);

            Assert.False(InvitationRules.Accept(invitation, Email).IsValid, $"aceptar desde {status}");
            Assert.False(InvitationRules.Reject(invitation, Email).IsValid, $"rechazar desde {status}");
            Assert.False(InvitationRules.Cancel(invitation).IsValid, $"cancelar desde {status}");
        }
    }

    [Fact]
    public void Desde_pendiente_hay_exactamente_tres_transiciones()
    {
        var pending = WithStatus(InvitationStatus.Pending);

        var reached = new[]
        {
            InvitationRules.Accept(pending, Email).Invitation!.Status,
            InvitationRules.Reject(pending, Email).Invitation!.Status,
            InvitationRules.Cancel(pending).Invitation!.Status,
        };

        Assert.Equal(
            [InvitationStatus.Accepted, InvitationStatus.Rejected, InvitationStatus.Cancelled],
            reached);
    }

    [Fact]
    public void Una_transicion_no_modifica_la_invitacion_original()
    {
        var pending = WithStatus(InvitationStatus.Pending);

        _ = InvitationRules.Accept(pending, Email);

        Assert.Equal(InvitationStatus.Pending, pending.Status);
    }

    [Fact]
    public void La_invitacion_no_caduca_con_el_tiempo()
    {
        // RF-10: vigente hasta que se acepte o un dueño la cancele; no hay fecha de vencimiento.
        Assert.DoesNotContain(
            typeof(Invitation).GetProperties(),
            p => p.PropertyType == typeof(DateTime) || p.PropertyType == typeof(DateTimeOffset));
    }

    [Fact]
    public void Los_codigos_de_error_son_estables()
    {
        Assert.Equal("invitation_not_pending", InvitationError.NotPending.Code());
        Assert.Equal("invitation_not_invitee", InvitationError.NotInvitee.Code());
    }

    [Fact]
    public void Los_ids_de_estado_son_estables()
    {
        Assert.Equal("pending", InvitationStatus.Pending.Id());
        Assert.Equal("accepted", InvitationStatus.Accepted.Id());
        Assert.Equal("rejected", InvitationStatus.Rejected.Id());
        Assert.Equal("cancelled", InvitationStatus.Cancelled.Id());
    }
}
