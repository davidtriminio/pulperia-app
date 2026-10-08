using System.Text.Json;

namespace Pulperia.Application.Operations;

/// <summary>
/// Lectura tolerante del payload JSON de una operación. Un campo ausente o con <c>null</c> se
/// lee como ausente; uno con un tipo equivocado hace fallar la lectura (<c>invalid_payload</c>).
/// </summary>
internal readonly struct Payload
{
    private readonly JsonElement _root;

    private Payload(JsonElement root) => _root = root;

    /// <summary>Null si el payload no es un objeto JSON.</summary>
    public static Payload? Of(JsonElement element) =>
        element.ValueKind == JsonValueKind.Object ? new Payload(element) : null;

    private bool TryGet(string name, out JsonElement value)
    {
        if (_root.TryGetProperty(name, out value) && value.ValueKind != JsonValueKind.Null)
        {
            return true;
        }
        value = default;
        return false;
    }

    /// <summary>Un texto opcional. Lanza <see cref="InvalidPayloadException"/> si no es texto.</summary>
    public string? String(string name)
    {
        if (!TryGet(name, out var value))
        {
            return null;
        }
        return value.ValueKind == JsonValueKind.String ? value.GetString() : throw new InvalidPayloadException();
    }

    /// <summary>Un entero opcional. Lanza <see cref="InvalidPayloadException"/> si no es entero.</summary>
    public long? Long(string name)
    {
        if (!TryGet(name, out var value))
        {
            return null;
        }
        return value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number)
            ? number
            : throw new InvalidPayloadException();
    }

    /// <summary>Un identificador opcional. Lanza <see cref="InvalidPayloadException"/> si no es un GUID.</summary>
    public Guid? Guid(string name)
    {
        var text = String(name);
        if (text is null)
        {
            return null;
        }
        return System.Guid.TryParse(text, out var id) ? id : throw new InvalidPayloadException();
    }

    /// <summary>Una fecha ISO 8601 opcional, en UTC. Lanza <see cref="InvalidPayloadException"/> si no lo es.</summary>
    public DateTimeOffset? Date(string name)
    {
        var text = String(name);
        if (text is null)
        {
            return null;
        }
        return DateTimeOffset.TryParse(text, System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.AssumeUniversal, out var date)
            ? date.ToUniversalTime()
            : throw new InvalidPayloadException();
    }

    /// <summary>Una lista opcional de objetos. Lanza <see cref="InvalidPayloadException"/> si no lo es.</summary>
    public IReadOnlyList<Payload>? Objects(string name)
    {
        if (!TryGet(name, out var value))
        {
            return null;
        }
        if (value.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidPayloadException();
        }
        return value.EnumerateArray()
            .Select(item => Of(item) ?? throw new InvalidPayloadException())
            .ToList();
    }
}

/// <summary>El payload de una operación no tiene la forma esperada.</summary>
internal sealed class InvalidPayloadException : Exception;
