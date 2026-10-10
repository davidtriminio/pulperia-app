namespace Pulperia.Domain.Admin;

/// <summary>
/// Acción de administración de la plataforma que deja constancia en la auditoría (RF-81, RF-101):
/// las de los comandos del servidor y las del panel de super administradores.
/// </summary>
public enum AdminAction
{
    ResetPassword,
    GrantSuperAdmin,
    RevokeSuperAdmin,
    SuspendBusiness,
    ReactivateBusiness,
    ActivateBusiness,
    SuspendAccount,
    ReactivateAccount,
}

public static class AdminActions
{
    /// <summary>Identificador estable, el mismo de la base de datos.</summary>
    public static string Id(this AdminAction action) => action switch
    {
        AdminAction.ResetPassword => "reset_password",
        AdminAction.GrantSuperAdmin => "grant_superadmin",
        AdminAction.RevokeSuperAdmin => "revoke_superadmin",
        AdminAction.SuspendBusiness => "suspend_business",
        AdminAction.ReactivateBusiness => "reactivate_business",
        AdminAction.ActivateBusiness => "activate_business",
        AdminAction.SuspendAccount => "suspend_account",
        AdminAction.ReactivateAccount => "reactivate_account",
        _ => throw new ArgumentOutOfRangeException(nameof(action)),
    };

    public static AdminAction FromId(string id) => id switch
    {
        "reset_password" => AdminAction.ResetPassword,
        "grant_superadmin" => AdminAction.GrantSuperAdmin,
        "revoke_superadmin" => AdminAction.RevokeSuperAdmin,
        "suspend_business" => AdminAction.SuspendBusiness,
        "reactivate_business" => AdminAction.ReactivateBusiness,
        "activate_business" => AdminAction.ActivateBusiness,
        "suspend_account" => AdminAction.SuspendAccount,
        "reactivate_account" => AdminAction.ReactivateAccount,
        _ => throw new ArgumentException($"Acción de administrador desconocida: {id}", nameof(id)),
    };
}

/// <summary>Motivo por el que se rechaza marcar o retirar la marca de super administrador.</summary>
public enum SuperAdminError
{
    AlreadySuperAdmin,
    NotSuperAdmin,
    LastSuperAdmin,
}

public static class SuperAdminErrors
{
    /// <summary>Código estable para los clientes y los comandos (RNF-5).</summary>
    public static string Code(this SuperAdminError error) => error switch
    {
        SuperAdminError.AlreadySuperAdmin => "already_super_admin",
        SuperAdminError.NotSuperAdmin => "not_super_admin",
        SuperAdminError.LastSuperAdmin => "last_super_admin",
        _ => throw new ArgumentOutOfRangeException(nameof(error)),
    };
}

public readonly record struct SuperAdminChange(bool IsValid, SuperAdminError? Error)
{
    public static SuperAdminChange Ok() => new(true, null);

    public static SuperAdminChange Deny(SuperAdminError error) => new(false, error);
}

/// <summary>
/// Reglas de la marca de super administrador (RF-95): marcar a quien no lo es, retirarla solo a
/// quien la tiene y nunca al último, para que la plataforma siempre tenga quien la administre.
/// </summary>
public static class SuperAdminRules
{
    public static SuperAdminChange Grant(bool isSuperAdmin) =>
        isSuperAdmin ? SuperAdminChange.Deny(SuperAdminError.AlreadySuperAdmin) : SuperAdminChange.Ok();

    /// <param name="isSuperAdmin">Si la cuenta a la que se le retira la tiene ahora.</param>
    /// <param name="superAdminCount">Cuántas cuentas la tienen ahora, contando esa.</param>
    public static SuperAdminChange Revoke(bool isSuperAdmin, int superAdminCount)
    {
        if (!isSuperAdmin)
        {
            return SuperAdminChange.Deny(SuperAdminError.NotSuperAdmin);
        }
        return superAdminCount <= 1
            ? SuperAdminChange.Deny(SuperAdminError.LastSuperAdmin)
            : SuperAdminChange.Ok();
    }
}
