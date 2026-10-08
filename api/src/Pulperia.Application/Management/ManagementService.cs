using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;
using Pulperia.Domain.Business;

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
}
