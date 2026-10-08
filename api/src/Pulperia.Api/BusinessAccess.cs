using Pulperia.Api.Endpoints;
using Pulperia.Application.Accounts;
using Pulperia.Domain.Access;

namespace Pulperia.Api;

/// <summary>El usuario, el negocio activo de la petición y el rol del usuario en él (RF-6).</summary>
public sealed record ActiveBusiness(Guid UserId, Guid BusinessId, Role Role);

/// <summary>El usuario autenticado y el negocio que nombra la petición, sin haber comprobado aún su pertenencia.</summary>
public sealed record BusinessCaller(Guid UserId, Guid BusinessId);

/// <summary>
/// Filtro de las rutas de un negocio: exige un token de acceso vigente y la cabecera
/// <c>X-Business-Id</c>, y comprueba en cada petición que el usuario sea miembro activo de ese
/// negocio (RF-50, D-27). Así quitar a alguien surte efecto en su siguiente petición.
/// </summary>
public static class BusinessAccess
{
    public const string BusinessHeader = "X-Business-Id";

    private const string ItemKey = "Pulperia.ActiveBusiness";
    private const string CallerKey = "Pulperia.BusinessCaller";

    /// <summary>Protege la ruta: 401 sin sesión, 400 sin negocio, 403 si el usuario no pertenece a él.</summary>
    public static TBuilder RequireBusiness<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.AddEndpointFilter(async (invocation, next) =>
        {
            var context = invocation.HttpContext;
            var accounts = context.RequestServices.GetRequiredService<AccountService>();

            if (await Http.AuthenticateAsync(context, accounts) is not { } user)
            {
                return Http.Unauthorized();
            }
            if (!Guid.TryParse(context.Request.Headers[BusinessHeader].ToString(), out var businessId))
            {
                return Http.Error(StatusCodes.Status400BadRequest, "business_required");
            }
            // Un negocio inexistente se rechaza igual que uno ajeno: no se revela cuáles existen.
            if (await accounts.AuthorizeBusinessAsync(user.UserId, businessId, context.RequestAborted) is not { } role)
            {
                return Http.Error(StatusCodes.Status403Forbidden, "forbidden");
            }

            context.Items[ItemKey] = new ActiveBusiness(user.UserId, businessId, role);
            return await next(invocation);
        });

    /// <summary>
    /// Exige además un permiso del rol del usuario en el negocio activo (RF-13). Va después de
    /// <see cref="RequireBusiness"/> y antes de leer el cuerpo, así que a un empleado se le
    /// rechaza con 403 sea cual sea lo que envíe.
    /// </summary>
    public static TBuilder RequirePermission<TBuilder>(this TBuilder builder, Permission permission)
        where TBuilder : IEndpointConventionBuilder =>
        builder.AddEndpointFilter(async (invocation, next) =>
            RolePermissions.Can(invocation.HttpContext.GetActiveBusiness().Role, permission)
                ? await next(invocation)
                : Http.Error(StatusCodes.Status403Forbidden, "forbidden"));

    /// <summary>
    /// Para las rutas de sincronización: exige sesión y la cabecera <c>X-Business-Id</c>, pero no
    /// comprueba la pertenencia, porque quien decide es el servicio: un empleado removido puede
    /// enviar un último lote (RF-12, T081). Quien no pertenece al negocio recibe 403 igualmente.
    /// </summary>
    public static TBuilder RequireBusinessCaller<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.AddEndpointFilter(async (invocation, next) =>
        {
            var context = invocation.HttpContext;
            var accounts = context.RequestServices.GetRequiredService<AccountService>();

            if (await Http.AuthenticateAsync(context, accounts) is not { } user)
            {
                return Http.Unauthorized();
            }
            if (!Guid.TryParse(context.Request.Headers[BusinessHeader].ToString(), out var businessId))
            {
                return Http.Error(StatusCodes.Status400BadRequest, "business_required");
            }

            context.Items[CallerKey] = new BusinessCaller(user.UserId, businessId);
            return await next(invocation);
        });

    /// <summary>Quien llama a una ruta protegida con <see cref="RequireBusinessCaller"/>.</summary>
    public static BusinessCaller GetBusinessCaller(this HttpContext context) =>
        context.Items[CallerKey] as BusinessCaller
        ?? throw new InvalidOperationException("La ruta no está protegida con RequireBusinessCaller().");

    /// <summary>El negocio activo de una ruta protegida con <see cref="RequireBusiness"/>.</summary>
    public static ActiveBusiness GetActiveBusiness(this HttpContext context) =>
        context.Items[ItemKey] as ActiveBusiness
        ?? throw new InvalidOperationException("La ruta no está protegida con RequireBusiness().");
}
