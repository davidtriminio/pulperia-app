using Pulperia.Domain.Business;

namespace Pulperia.Application.Management;

/// <summary>Nombre y modos del negocio (RF-7, RF-80).</summary>
public sealed record BusinessSettings(string Name, AmountMode AmountMode, QuantityMode QuantityMode);

/// <summary>Un cambio parcial de ajustes: lo que sea null no se toca.</summary>
public sealed record SettingsChange(string? Name = null, AmountMode? AmountMode = null, QuantityMode? QuantityMode = null);
