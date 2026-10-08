namespace Pulperia.Application.Operations;

/// <summary>
/// Aplica una operación de un dispositivo al negocio: valida con las reglas del dominio y guarda
/// (D-4). Nunca lanza por una operación mala: la rechaza con un código estable.
/// </summary>
public sealed class OperationApplier(IOperationStore store)
{
    public async Task<OperationResult> ApplyAsync(
        Operation operation, OperationActor actor, CancellationToken cancellationToken = default)
    {
        try
        {
            return operation.Type switch
            {
                "client.create" => await ClientOperations.CreateAsync(store, operation, actor, cancellationToken),
                "client.update" => await ClientOperations.UpdateAsync(store, operation, cancellationToken),
                "client.archive" => await ClientOperations.SetArchivedAsync(store, operation, true, cancellationToken),
                "client.restore" => await ClientOperations.SetArchivedAsync(store, operation, false, cancellationToken),
                "product.create" => await ProductOperations.CreateAsync(store, operation, actor, cancellationToken),
                "product.update" => await ProductOperations.UpdateAsync(store, operation, cancellationToken),
                "product.archive" => await ProductOperations.ArchiveAsync(store, operation, cancellationToken),
                "fiado.create" => await FiadoOperations.CreateAsync(store, operation, actor, cancellationToken),
                "payment.create" => await PaymentOperations.CreateAsync(store, operation, actor, cancellationToken),
                "fiado.annul" => await AnnulmentOperations.AnnulFiadoAsync(store, operation, actor, cancellationToken),
                "payment.annul" => await AnnulmentOperations.AnnulPaymentAsync(store, operation, actor, cancellationToken),
                _ => OperationResult.Rejected(RejectionCodes.UnknownOperation),
            };
        }
        catch (InvalidPayloadException)
        {
            return OperationResult.Rejected(RejectionCodes.InvalidPayload);
        }
    }
}

/// <summary>Códigos de rechazo que no vienen de una validación del dominio.</summary>
public static class RejectionCodes
{
    public const string UnknownOperation = "unknown_operation";
    public const string InvalidPayload = "invalid_payload";
    public const string EntityAlreadyExists = "entity_already_exists";
    public const string VersionConflict = "version_conflict";
    public const string BaseVersionRequired = "base_version_required";
    public const string ClientNotFound = "client_not_found";
    public const string ProductNotFound = "product_not_found";
    public const string FiadoNotFound = "fiado_not_found";
    public const string PaymentNotFound = "payment_not_found";
    public const string DuplicateItemId = "duplicate_item_id";
    public const string ItemUnitUnknown = "item_unit_unknown";
    public const string SubtotalMismatch = "subtotal_mismatch";
    public const string TotalMismatch = "total_mismatch";
}
