using System.Text.Json;
using System.Text.RegularExpressions;

namespace Pulperia.Tests.Support;

/// <summary>
/// El contrato <c>shared/openapi.json</c> (D-17) y un validador mínimo de sus esquemas, sin
/// paquetes: tipos, formatos uuid y date-time, enums, requeridos, <c>nullable</c>, <c>allOf</c>,
/// <c>oneOf</c> y <c>$ref</c>. Es estricto a propósito: un objeto no puede traer propiedades que el
/// contrato no declare, así que el contrato y la API no se desvían en silencio.
/// </summary>
public sealed partial class OpenApiContract
{
    private readonly JsonElement _root;

    private OpenApiContract(JsonElement root) => _root = root;

    [GeneratedRegex(@"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d:\d\d)$")]
    private static partial Regex DateTimePattern();

    /// <summary>Lee <c>shared/openapi.json</c>, buscándolo hacia arriba desde el binario de pruebas.</summary>
    public static OpenApiContract Load()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "shared", "openapi.json");
            if (File.Exists(candidate))
            {
                return new OpenApiContract(JsonDocument.Parse(File.ReadAllText(candidate)).RootElement.Clone());
            }
            dir = dir.Parent;
        }
        throw new FileNotFoundException("No se encontró shared/openapi.json desde " + AppContext.BaseDirectory);
    }

    private static readonly string[] Methods = ["get", "post", "put", "patch", "delete"];

    /// <summary>Cada operación del contrato como (MÉTODO, ruta con {parámetros}).</summary>
    public IEnumerable<(string Method, string Path)> Operations() =>
        _root.GetProperty("paths").EnumerateObject().SelectMany(p =>
            p.Value.EnumerateObject().Where(o => Methods.Contains(o.Name)).Select(o => (o.Name.ToUpperInvariant(), p.Name)));

    /// <summary>Cada respuesta documentada como (MÉTODO, ruta, estado).</summary>
    public IEnumerable<(string Method, string Path, int Status)> Responses() =>
        Operations().SelectMany(o => Operation(o.Method, o.Path)!.Value.GetProperty("responses").EnumerateObject()
            .Select(r => (o.Method, o.Path, int.Parse(r.Name))));

    public JsonElement? Operation(string method, string path) =>
        _root.GetProperty("paths").TryGetProperty(path, out var item) && item.TryGetProperty(method.ToLowerInvariant(), out var op)
            ? op
            : null;

    public bool IsDocumented(string method, string path, int status) =>
        Operation(method, path) is { } op && op.GetProperty("responses").TryGetProperty(status.ToString(), out _);

    /// <summary>El esquema del cuerpo de la respuesta, o null si no documenta cuerpo (por ejemplo un 204).</summary>
    public JsonElement? ResponseSchema(string method, string path, int status)
    {
        var response = Resolve(Operation(method, path)!.Value.GetProperty("responses").GetProperty(status.ToString()));
        return response.TryGetProperty("content", out var content) && content.TryGetProperty("application/json", out var json)
            ? json.GetProperty("schema")
            : null;
    }

    /// <summary>El esquema del cuerpo de la petición, o null si la operación no recibe cuerpo.</summary>
    public JsonElement? RequestSchema(string method, string path) =>
        Operation(method, path)!.Value.TryGetProperty("requestBody", out var body)
            ? Resolve(body).GetProperty("content").GetProperty("application/json").GetProperty("schema")
            : null;

    /// <summary>Los problemas del valor frente al esquema; vacío si lo cumple.</summary>
    public List<string> Validate(JsonElement value, JsonElement schema)
    {
        var errors = new List<string>();
        Check(value, schema, "$", errors);
        return errors;
    }

    /// <summary>Sigue los <c>$ref</c> (punteros JSON como <c>#/components/schemas/X/properties/y</c>).</summary>
    private JsonElement Resolve(JsonElement node)
    {
        while (node.ValueKind == JsonValueKind.Object && node.TryGetProperty("$ref", out var reference))
        {
            var current = _root;
            foreach (var part in reference.GetString()!.TrimStart('#', '/').Split('/'))
            {
                current = current.GetProperty(part);
            }
            node = current;
        }
        return node;
    }

    private void Gather(JsonElement schema, Dictionary<string, JsonElement> properties, HashSet<string> required)
    {
        schema = Resolve(schema);
        if (schema.TryGetProperty("allOf", out var all))
        {
            foreach (var part in all.EnumerateArray())
            {
                Gather(part, properties, required);
            }
        }
        if (schema.TryGetProperty("properties", out var props))
        {
            foreach (var property in props.EnumerateObject())
            {
                properties[property.Name] = property.Value;
            }
        }
        if (schema.TryGetProperty("required", out var req))
        {
            foreach (var name in req.EnumerateArray())
            {
                required.Add(name.GetString()!);
            }
        }
    }

    private void Check(JsonElement value, JsonElement node, string path, List<string> errors)
    {
        var schema = Resolve(node);

        if (schema.TryGetProperty("oneOf", out var options))
        {
            var matches = options.EnumerateArray().Count(option =>
            {
                var inner = new List<string>();
                Check(value, option, path, inner);
                return inner.Count == 0;
            });
            if (matches != 1)
            {
                errors.Add($"{path}: debe cumplir exactamente una de las {options.GetArrayLength()} opciones y cumple {matches}");
            }
            return;
        }

        if (value.ValueKind == JsonValueKind.Null)
        {
            if (!(schema.TryGetProperty("nullable", out var nullable) && nullable.GetBoolean()))
            {
                errors.Add($"{path}: es null y el contrato no lo permite");
            }
            return;
        }

        var type = schema.TryGetProperty("type", out var t) ? t.GetString() : schema.TryGetProperty("allOf", out _) ? "object" : null;
        switch (type)
        {
            case "object":
                CheckObject(value, schema, path, errors);
                break;
            case "array":
                if (value.ValueKind != JsonValueKind.Array)
                {
                    errors.Add($"{path}: debe ser un arreglo");
                    break;
                }
                if (schema.TryGetProperty("maxItems", out var max) && value.GetArrayLength() > max.GetInt32())
                {
                    errors.Add($"{path}: más de {max.GetInt32()} elementos");
                }
                var index = 0;
                foreach (var item in value.EnumerateArray())
                {
                    Check(item, schema.GetProperty("items"), $"{path}[{index++}]", errors);
                }
                break;
            case "string":
                CheckString(value, schema, path, errors);
                break;
            case "integer":
                if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt64(out _))
                {
                    errors.Add($"{path}: debe ser un entero y es {value.ValueKind}");
                }
                break;
            case "boolean":
                if (value.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                {
                    errors.Add($"{path}: debe ser booleano y es {value.ValueKind}");
                }
                break;
            default:
                throw new InvalidOperationException($"{path}: el validador no conoce el tipo '{type}'.");
        }
    }

    private void CheckObject(JsonElement value, JsonElement schema, string path, List<string> errors)
    {
        if (value.ValueKind != JsonValueKind.Object)
        {
            errors.Add($"{path}: debe ser un objeto y es {value.ValueKind}");
            return;
        }

        var properties = new Dictionary<string, JsonElement>();
        var required = new HashSet<string>();
        Gather(schema, properties, required);
        var open = schema.TryGetProperty("additionalProperties", out var additional) && additional.ValueKind == JsonValueKind.True;

        foreach (var name in required.Where(n => !value.TryGetProperty(n, out _)))
        {
            errors.Add($"{path}: falta la propiedad requerida '{name}'");
        }
        foreach (var property in value.EnumerateObject())
        {
            if (properties.TryGetValue(property.Name, out var propertySchema))
            {
                Check(property.Value, propertySchema, $"{path}.{property.Name}", errors);
            }
            else if (!open)
            {
                errors.Add($"{path}: la propiedad '{property.Name}' no está en el contrato");
            }
        }
    }

    private void CheckString(JsonElement value, JsonElement schema, string path, List<string> errors)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            errors.Add($"{path}: debe ser texto y es {value.ValueKind}");
            return;
        }
        var text = value.GetString()!;
        if (schema.TryGetProperty("enum", out var allowed) && !allowed.EnumerateArray().Any(a => a.GetString() == text))
        {
            errors.Add($"{path}: '{text}' no es uno de los valores del contrato");
        }
        if (schema.TryGetProperty("format", out var format))
        {
            switch (format.GetString())
            {
                case "uuid" when !Guid.TryParse(text, out _):
                    errors.Add($"{path}: '{text}' no es un uuid");
                    break;
                case "date-time" when !DateTimePattern().IsMatch(text) || !DateTimeOffset.TryParse(text, out _):
                    errors.Add($"{path}: '{text}' no es una fecha ISO 8601 con zona");
                    break;
            }
        }
    }
}
