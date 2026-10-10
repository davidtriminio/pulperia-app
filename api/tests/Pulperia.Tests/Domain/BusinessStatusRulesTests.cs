using Pulperia.Domain.Business;

namespace Pulperia.Tests.Domain;

/// <summary>T186: estados del negocio y sus transiciones válidas (RF-98, RF-102, RF-103, D-30).</summary>
public class BusinessStatusRulesTests
{
    [Theory]
    [InlineData(BusinessStatus.Pending, "pending")]
    [InlineData(BusinessStatus.Active, "active")]
    [InlineData(BusinessStatus.Suspended, "suspended")]
    public void Cada_estado_tiene_su_identificador_estable(BusinessStatus status, string id)
    {
        Assert.Equal(id, status.Id());
        Assert.Equal(status, BusinessStatuses.FromId(id));
    }

    [Fact]
    public void Un_identificador_desconocido_se_rechaza()
    {
        Assert.Throws<ArgumentException>(() => BusinessStatuses.FromId("archived"));
    }

    [Fact]
    public void Activar_solo_vale_para_un_negocio_pendiente()
    {
        Assert.Equal(BusinessStatus.Active, BusinessStatusRules.Activate(BusinessStatus.Pending).Status);
        Assert.Equal(BusinessStatusError.InvalidTransition, BusinessStatusRules.Activate(BusinessStatus.Active).Error);
        Assert.Equal(BusinessStatusError.InvalidTransition, BusinessStatusRules.Activate(BusinessStatus.Suspended).Error);
    }

    [Theory]
    [InlineData(BusinessStatus.Pending)]
    [InlineData(BusinessStatus.Active)]
    public void Suspender_vale_para_un_negocio_pendiente_o_activo_y_exige_motivo(BusinessStatus from)
    {
        var result = BusinessStatusRules.Suspend(from, "Falta de pago");

        Assert.True(result.IsValid);
        Assert.Equal(BusinessStatus.Suspended, result.Status);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Suspender_sin_motivo_se_rechaza(string? reason)
    {
        var result = BusinessStatusRules.Suspend(BusinessStatus.Active, reason);

        Assert.False(result.IsValid);
        Assert.Equal(BusinessStatusError.ReasonRequired, result.Error);
    }

    [Fact]
    public void Suspender_uno_ya_suspendido_es_una_transicion_invalida()
    {
        var result = BusinessStatusRules.Suspend(BusinessStatus.Suspended, "otra vez");

        Assert.Equal(BusinessStatusError.InvalidTransition, result.Error);
    }

    [Fact]
    public void Reactivar_solo_vale_para_un_negocio_suspendido()
    {
        Assert.Equal(BusinessStatus.Active, BusinessStatusRules.Reactivate(BusinessStatus.Suspended).Status);
        Assert.Equal(BusinessStatusError.InvalidTransition, BusinessStatusRules.Reactivate(BusinessStatus.Active).Error);
        Assert.Equal(BusinessStatusError.InvalidTransition, BusinessStatusRules.Reactivate(BusinessStatus.Pending).Error);
    }

    [Theory]
    [InlineData(BusinessStatusError.InvalidTransition, "business_status_invalid_transition")]
    [InlineData(BusinessStatusError.ReasonRequired, "reason_required")]
    public void Cada_error_tiene_su_codigo_estable(BusinessStatusError error, string code)
    {
        Assert.Equal(code, error.Code());
    }
}
