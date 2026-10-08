namespace Pulperia.Domain.Admin;

/// <summary>Acción manual del administrador del servidor que deja constancia en la auditoría (RF-81).</summary>
public enum AdminAction
{
    ResetPassword,
}

public static class AdminActions
{
    /// <summary>Identificador estable, el mismo de la base de datos.</summary>
    public static string Id(this AdminAction action) => action switch
    {
        AdminAction.ResetPassword => "reset_password",
        _ => throw new ArgumentOutOfRangeException(nameof(action)),
    };

    public static AdminAction FromId(string id) => id switch
    {
        "reset_password" => AdminAction.ResetPassword,
        _ => throw new ArgumentException($"Acción de administrador desconocida: {id}", nameof(id)),
    };
}
