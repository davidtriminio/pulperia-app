using Pulperia.Domain.Access;
using Pulperia.Domain.Business;
using Pulperia.Domain.Invitations;

namespace Pulperia.Application.Management;

/// <summary>Nombre y modos del negocio (RF-7, RF-80).</summary>
public sealed record BusinessSettings(string Name, AmountMode AmountMode, QuantityMode QuantityMode);

/// <summary>Un cambio parcial de ajustes: lo que sea null no se toca.</summary>
public sealed record SettingsChange(string? Name = null, AmountMode? AmountMode = null, QuantityMode? QuantityMode = null);

/// <summary>Una invitación de un negocio a un correo (RF-10).</summary>
/// <param name="Email">Null en una invitación solo por código.</param>
/// <param name="Code">El código de un solo uso, en su forma para mostrar (<c>XXXX-XXXX</c>); solo lo ve el dueño (RF-92).</param>
public sealed record InvitationView(Guid Id, Guid BusinessId, string? Email, InvitationStatus Status, string Code);

/// <summary>Una invitación pendiente tal como la ve quien la recibe (RF-67).</summary>
public sealed record InvitationOffer(Guid Id, Guid BusinessId, string BusinessName, string Email);

/// <summary>Un miembro activo del equipo, con el correo de su cuenta (RF-70).</summary>
public sealed record TeamMemberView(Guid UserId, string Email, Role Role);
