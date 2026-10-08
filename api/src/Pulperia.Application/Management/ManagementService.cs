using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Accounts;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;
using Pulperia.Domain.Team;

namespace Pulperia.Application.Management;

/// <summary>
/// Ajustes, invitaciones y equipo del negocio. Solo el dueño gestiona (RF-13): cada método
/// recibe el rol del usuario en el negocio activo y rechaza con <c>forbidden</c> al empleado
/// antes de mirar nada más.
/// </summary>
public sealed class ManagementService(IManagementStore store, TimeProvider clock)
{
    private const string Forbidden = "forbidden";

    /// <summary>Nombre y modos del negocio, para el dueño.</summary>
    public async Task<AccountResult<BusinessSettings>> GetSettingsAsync(
        Guid businessId, Role role, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageBusinessSettings))
        {
            return AccountResult<BusinessSettings>.Fail(Forbidden);
        }
        return await store.GetSettingsAsync(businessId, cancellationToken) is { } settings
            ? AccountResult<BusinessSettings>.Ok(settings)
            : AccountResult<BusinessSettings>.Fail("business_not_found");
    }

    /// <summary>
    /// Cambia el nombre y los modos (RF-7 a RF-9, RF-80). Pasar de decimales a enteros se
    /// rechaza; un cambio con un campo inválido no aplica ninguno de los otros.
    /// </summary>
    public async Task<AccountResult<BusinessSettings>> UpdateSettingsAsync(
        Guid businessId, Role role, SettingsChange change, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageBusinessSettings))
        {
            return AccountResult<BusinessSettings>.Fail(Forbidden);
        }
        if (await store.GetSettingsAsync(businessId, cancellationToken) is not { } current)
        {
            return AccountResult<BusinessSettings>.Fail("business_not_found");
        }

        var problems = new List<string>();
        var name = current.Name;
        if (change.Name is not null)
        {
            if (Pulperia.Domain.Accounts.AccountRules.BusinessNameError(change.Name) is { } nameError)
            {
                problems.Add(nameError);
            }
            else
            {
                name = change.Name.Trim();
            }
        }
        var amountMode = change.AmountMode ?? current.AmountMode;
        if (change.AmountMode is { } requestedAmount
            && ModeChanges.ChangeAmountMode(current.AmountMode, requestedAmount) is { Allowed: false, Error: { } amountError })
        {
            problems.Add(amountError.Code());
        }
        var quantityMode = change.QuantityMode ?? current.QuantityMode;
        if (change.QuantityMode is { } requestedQuantity
            && ModeChanges.ChangeQuantityMode(current.QuantityMode, requestedQuantity) is { Allowed: false, Error: { } quantityError })
        {
            problems.Add(quantityError.Code());
        }
        if (problems.Count > 0)
        {
            return AccountResult<BusinessSettings>.Fail(problems.Distinct().ToList());
        }

        var updated = new BusinessSettings(name, amountMode, quantityMode);
        if (updated != current)
        {
            await store.UpdateSettingsAsync(businessId, updated, cancellationToken);
        }
        return AccountResult<BusinessSettings>.Ok(updated);
    }

    /// <summary>
    /// Un dueño invita (RF-10, RF-92). Con correo, la invitación la ve esa persona al iniciar sesión;
    /// sin correo (<c>null</c>), solo se activa con el código. En los dos casos lleva un código de
    /// un solo uso que el dueño puede entregar por cualquier medio.
    /// </summary>
    public async Task<AccountResult<InvitationView>> InviteAsync(
        Guid businessId, Role role, Guid createdBy, string? email, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<InvitationView>.Fail(Forbidden);
        }
        string? normalized = null;
        if (email is not null)
        {
            normalized = InvitationRules.NormalizeEmail(email);
            if (!AccountRules.IsValidEmail(normalized))
            {
                return AccountResult<InvitationView>.Fail("email_invalid");
            }
            if (await store.IsActiveMemberByEmailAsync(businessId, normalized, cancellationToken))
            {
                return AccountResult<InvitationView>.Fail("already_member");
            }
            if (await store.HasPendingInvitationAsync(businessId, normalized, cancellationToken))
            {
                return AccountResult<InvitationView>.Fail("invitation_already_pending");
            }
        }

        // El código es único en toda la tabla: si por azar choca con otro, se genera uno nuevo.
        for (var attempt = 0; attempt < 5; attempt++)
        {
            var invitation = InvitationRules.Create(Guid.CreateVersion7(), businessId, normalized, InvitationCodes.Generate());
            if (await store.TryAddInvitationAsync(invitation, createdBy, clock.GetUtcNow().UtcDateTime, cancellationToken))
            {
                return AccountResult<InvitationView>.Ok(ToView(invitation));
            }
        }
        throw new InvalidOperationException("No se pudo generar un código de invitación único.");
    }

    /// <summary>
    /// Canjear un código (RF-93, RF-94): quien lo escribe entra al negocio como empleado, sin importar
    /// su correo. Un código inexistente, usado, cancelado o mal escrito da el mismo rechazo, sin decir
    /// nada de ningún negocio. Quien ya es miembro activo no lo consume ni cambia de rol.
    /// </summary>
    public async Task<AccountResult<BusinessSummary>> RedeemInvitationCodeAsync(
        Guid userId, string? typedCode, CancellationToken cancellationToken = default)
    {
        const string invalid = "invalid_invitation_code";
        if (InvitationCodes.Normalize(typedCode) is not { } code
            || await store.FindPendingInvitationByCodeAsync(code, cancellationToken) is not { } invitation)
        {
            return AccountResult<BusinessSummary>.Fail(invalid);
        }
        if (await store.IsActiveMemberAsync(userId, invitation.BusinessId, cancellationToken))
        {
            return AccountResult<BusinessSummary>.Fail("already_member");
        }
        if (!InvitationRules.AcceptByCode(invitation).IsValid
            || !await store.AcceptInvitationAsync(invitation.Id, userId, cancellationToken))
        {
            return AccountResult<BusinessSummary>.Fail(invalid);
        }

        var settings = await store.GetSettingsAsync(invitation.BusinessId, cancellationToken);
        return AccountResult<BusinessSummary>.Ok(new BusinessSummary(
            invitation.BusinessId, settings!.Name, Role.Employee, settings.AmountMode, settings.QuantityMode));
    }

    /// <summary>Las invitaciones pendientes del negocio, para que el dueño pueda cancelarlas.</summary>
    public async Task<AccountResult<IReadOnlyList<InvitationView>>> ListBusinessInvitationsAsync(
        Guid businessId, Role role, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<IReadOnlyList<InvitationView>>.Fail(Forbidden);
        }
        var pending = await store.ListPendingInvitationsOfBusinessAsync(businessId, cancellationToken);
        return AccountResult<IReadOnlyList<InvitationView>>.Ok(pending.Select(ToView).ToList());
    }

    /// <summary>
    /// El dueño cancela una invitación pendiente de su negocio (RF-69). La de otro negocio se
    /// trata como inexistente. Una cancelada ya no puede aceptarse.
    /// </summary>
    public async Task<AccountResult<InvitationView>> CancelInvitationAsync(
        Guid businessId, Role role, Guid invitationId, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<InvitationView>.Fail(Forbidden);
        }
        if (await store.FindInvitationAsync(invitationId, cancellationToken) is not { } invitation
            || invitation.BusinessId != businessId)
        {
            return AccountResult<InvitationView>.Fail("invitation_not_found");
        }
        var result = InvitationRules.Cancel(invitation);
        if (!result.IsValid)
        {
            return AccountResult<InvitationView>.Fail(result.Error!.Value.Code());
        }
        return await store.CancelInvitationAsync(invitationId, cancellationToken)
            ? AccountResult<InvitationView>.Ok(ToView(result.Invitation!))
            : AccountResult<InvitationView>.Fail("invitation_not_pending");
    }

    /// <summary>Las invitaciones pendientes del usuario, por el correo de su cuenta (RF-67).</summary>
    public async Task<IReadOnlyList<InvitationOffer>> ListInvitationsForUserAsync(
        Guid userId, CancellationToken cancellationToken = default) =>
        await store.FindUserEmailAsync(userId, cancellationToken) is { } email
            ? await store.ListPendingInvitationsAsync(InvitationRules.NormalizeEmail(email), cancellationToken)
            : [];

    /// <summary>
    /// El invitado acepta (RF-68): entra al negocio como empleado, aunque ya pertenezca a otros.
    /// Devuelve el negocio con su rol.
    /// </summary>
    public async Task<AccountResult<BusinessSummary>> AcceptInvitationAsync(
        Guid userId, Guid invitationId, CancellationToken cancellationToken = default)
    {
        var (invitation, failure) = await ResolveAsync(userId, invitationId, InvitationRules.Accept, cancellationToken);
        if (failure is not null)
        {
            return AccountResult<BusinessSummary>.Fail(failure);
        }
        if (!await store.AcceptInvitationAsync(invitationId, userId, cancellationToken))
        {
            return AccountResult<BusinessSummary>.Fail("invitation_not_pending");
        }

        var settings = await store.GetSettingsAsync(invitation!.BusinessId, cancellationToken);
        return AccountResult<BusinessSummary>.Ok(new BusinessSummary(
            invitation.BusinessId, settings!.Name, Role.Employee, settings.AmountMode, settings.QuantityMode));
    }

    /// <summary>El invitado rechaza (RF-68): no se crea ninguna pertenencia.</summary>
    public async Task<AccountResult<InvitationView>> RejectInvitationAsync(
        Guid userId, Guid invitationId, CancellationToken cancellationToken = default)
    {
        var (invitation, failure) = await ResolveAsync(userId, invitationId, InvitationRules.Reject, cancellationToken);
        if (failure is not null)
        {
            return AccountResult<InvitationView>.Fail(failure);
        }
        return await store.RejectInvitationAsync(invitationId, cancellationToken)
            ? AccountResult<InvitationView>.Ok(ToView(invitation! with { Status = InvitationStatus.Rejected }))
            : AccountResult<InvitationView>.Fail("invitation_not_pending");
    }

    private async Task<(Invitation? Invitation, string? Failure)> ResolveAsync(
        Guid userId, Guid invitationId, Func<Invitation, string, InvitationResult> rule, CancellationToken cancellationToken)
    {
        if (await store.FindInvitationAsync(invitationId, cancellationToken) is not { } invitation)
        {
            return (null, "invitation_not_found");
        }
        var email = await store.FindUserEmailAsync(userId, cancellationToken) ?? "";
        var result = rule(invitation, email);
        return result.IsValid ? (invitation, null) : (null, result.Error!.Value.Code());
    }

    private static InvitationView ToView(Invitation invitation) =>
        new(invitation.Id, invitation.BusinessId, invitation.Email, invitation.Status, InvitationCodes.Format(invitation.Code!));

    /// <summary>El equipo activo del negocio: dueños primero, luego por correo (RF-70).</summary>
    public async Task<AccountResult<IReadOnlyList<TeamMemberView>>> ListTeamAsync(
        Guid businessId, Role role, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<IReadOnlyList<TeamMemberView>>.Fail(Forbidden);
        }
        var team = await store.ListActiveTeamAsync(businessId, cancellationToken);
        return AccountResult<IReadOnlyList<TeamMemberView>>.Ok(
            team.OrderBy(m => m.Role).ThenBy(m => m.Email, StringComparer.Ordinal).ToList());
    }

    /// <summary>Un dueño promueve a un empleado activo a dueño (RF-70): recibe todos los permisos de dueño.</summary>
    public async Task<AccountResult<Member>> PromoteAsync(
        Guid businessId, Role role, Guid userId, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<Member>.Fail(Forbidden);
        }
        var result = await store.ChangeTeamAsync(
            businessId, team => TeamRules.Promote(team, userId), clock.GetUtcNow().UtcDateTime, cancellationToken);
        return result.IsValid
            ? AccountResult<Member>.Ok(result.Team!.Single(m => m.UserId == userId))
            : AccountResult<Member>.Fail(result.Error!.Value.Code());
    }

    /// <summary>
    /// Un dueño quita a un miembro activo (RF-11, RF-71): pierde el acceso al negocio y nunca se
    /// puede quitar al último dueño, ni siquiera a sí mismo. Su último lote pendiente lo decide
    /// la sincronización (RF-12).
    /// </summary>
    public async Task<AccountResult<Member>> RemoveAsync(
        Guid businessId, Role role, Guid userId, CancellationToken cancellationToken = default)
    {
        if (!RolePermissions.Can(role, Permission.ManageTeam))
        {
            return AccountResult<Member>.Fail(Forbidden);
        }
        var result = await store.ChangeTeamAsync(
            businessId, team => TeamRules.Remove(team, userId), clock.GetUtcNow().UtcDateTime, cancellationToken);
        return result.IsValid
            ? AccountResult<Member>.Ok(result.Team!.Single(m => m.UserId == userId))
            : AccountResult<Member>.Fail(result.Error!.Value.Code());
    }
}
