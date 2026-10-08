using System.Text.Json;
using Pulperia.Domain.Amounts;
using Pulperia.Domain.Avatars;
using Pulperia.Domain.Business;
using Pulperia.Domain.Catalog;
using Pulperia.Domain.Clients;
using Pulperia.Tests.Support;

namespace Pulperia.Tests.Domain;

/// <summary>
/// Validación de cliente, avatar, teléfono, producto y unidad de venta: los mismos casos
/// que el móvil (T023, T024, T028, T034) y los vectores compartidos.
/// </summary>
public class ClientAndProductValidationTests
{
    public static TheoryData<string> NameCases => SharedVectors.Names("client-validation.json");
    public static TheoryData<string> PhoneCases => SharedVectors.Names("phone.json");

    private static ClientDraft Draft(
        string name = "Ana López",
        string? note = null,
        string? phone = null,
        string? address = null,
        string? characterId = "char-01",
        string? skinId = "skin-1",
        string? backgroundId = "bg-01") =>
        new(name, note, phone, address, characterId, skinId, backgroundId);

    private static List<(ClientField, string)> IssuesOf(ClientValidationResult result) =>
        result is InvalidClient invalid
            ? invalid.Issues.Select(i => (i.Field, i.Code)).ToList()
            : [];

    // ---- nombre y nota con los vectores compartidos (RF-15, RF-17, RF-74)

    [Fact]
    public void Hay_al_menos_25_casos_de_nombre_y_nota() =>
        Assert.True(SharedVectors.Load("client-validation.json").Count >= 25);

    [Theory]
    [MemberData(nameof(NameCases))]
    public void Nombre_y_nota_segun_los_vectores(string name)
    {
        var c = SharedVectors.Get("client-validation.json", name);
        var input = c.Input;
        var note = input.TryGetProperty("note", out var n) && n.ValueKind == JsonValueKind.String
            ? n.GetString()
            : null;
        var clientName = input.GetProperty("name").GetString()!;
        var existing = input.GetProperty("existingNames").EnumerateArray().Select(e => e.GetString()!).ToList();

        var result = ClientValidator.Validate(Draft(name: clientName, note: note));

        Assert.Equal(
            c.Expected.GetProperty("errors").EnumerateArray().Select(e => e.GetString()!).ToList(),
            IssuesOf(result).Select(i => i.Item2).ToList());
        Assert.Equal(
            c.Expected.GetProperty("duplicate").GetBoolean(),
            Homonyms.HasHomonym(clientName, existing));
    }

    // ---- teléfono con los vectores compartidos (RF-77)

    [Fact]
    public void Hay_al_menos_25_casos_de_telefono() =>
        Assert.True(SharedVectors.Load("phone.json").Count >= 25);

    [Theory]
    [MemberData(nameof(PhoneCases))]
    public void Telefono_segun_los_vectores(string name)
    {
        var c = SharedVectors.Get("phone.json", name);

        var result = ClientValidator.Validate(Draft(phone: c.Input.GetProperty("phone").GetString()));

        if (c.Expected.GetProperty("valid").GetBoolean())
        {
            Assert.Empty(IssuesOf(result));
        }
        else
        {
            Assert.Equal(
                [(ClientField.Phone, c.Expected.GetProperty("error").GetString()!)],
                IssuesOf(result));
        }
    }

    [Fact]
    public void El_telefono_es_opcional_y_vacio_cuenta_como_ausente()
    {
        Assert.Empty(IssuesOf(ClientValidator.Validate(Draft())));
        Assert.Empty(IssuesOf(ClientValidator.Validate(Draft(phone: ""))));
    }

    // ---- avatar completo (RF-16, RF-72)

    [Fact]
    public void Sin_nada_elegido_indica_que_falta()
    {
        var result = ClientValidator.Validate(Draft(characterId: null, skinId: null, backgroundId: null));

        Assert.Equal(
            [
                (ClientField.AvatarCharacter, "avatar_character_required"),
                (ClientField.AvatarSkin, "avatar_skin_required"),
                (ClientField.AvatarBackground, "avatar_background_required"),
            ],
            IssuesOf(result));
    }

    [Fact]
    public void Un_identificador_vacio_cuenta_como_no_elegido() =>
        Assert.Equal(
            [(ClientField.AvatarCharacter, "avatar_character_required")],
            IssuesOf(ClientValidator.Validate(Draft(characterId: ""))));

    [Fact]
    public void Un_componente_fuera_de_la_paleta_se_rechaza()
    {
        Assert.Equal(
            [(ClientField.AvatarCharacter, "avatar_character_unknown")],
            IssuesOf(ClientValidator.Validate(Draft(characterId: "char-99"))));
        Assert.Equal(
            [(ClientField.AvatarSkin, "avatar_skin_unknown")],
            IssuesOf(ClientValidator.Validate(Draft(skinId: "skin-9"))));
        Assert.Equal(
            [(ClientField.AvatarBackground, "avatar_background_unknown")],
            IssuesOf(ClientValidator.Validate(Draft(backgroundId: "bg-99"))));
    }

    [Fact]
    public void El_avatar_mas_alto_de_la_paleta_se_acepta() =>
        Assert.Empty(IssuesOf(ClientValidator.Validate(
            Draft(characterId: "char-24", skinId: "skin-6", backgroundId: "bg-12"))));

    [Fact]
    public void Varios_problemas_se_reportan_en_orden()
    {
        var result = ClientValidator.Validate(Draft(
            name: "  ", note: new string('x', 301), phone: "12345",
            characterId: null, skinId: null, backgroundId: null));

        Assert.Equal(
            [
                (ClientField.Name, "name_required"),
                (ClientField.Note, "note_too_long"),
                (ClientField.Phone, "phone_invalid_format"),
                (ClientField.AvatarCharacter, "avatar_character_required"),
                (ClientField.AvatarSkin, "avatar_skin_required"),
                (ClientField.AvatarBackground, "avatar_background_required"),
            ],
            IssuesOf(result));
    }

    [Fact]
    public void La_direccion_no_tiene_regla()
    {
        Assert.Empty(IssuesOf(ClientValidator.Validate(Draft(address: ""))));
        Assert.Empty(IssuesOf(ClientValidator.Validate(Draft(address: "Frente a la iglesia"))));
    }

    [Fact]
    public void Un_cliente_valido_devuelve_el_borrador_sin_modificarlo()
    {
        var original = Draft(name: "  Ana  ", note: "Paga los viernes", phone: "90000000");

        var result = ClientValidator.Validate(original);

        Assert.Same(original, Assert.IsType<ValidClient>(result).Draft);
    }

    [Fact]
    public void La_nota_de_300_caracteres_se_acepta_y_la_de_301_no()
    {
        Assert.Empty(IssuesOf(ClientValidator.Validate(Draft(note: new string('n', 300)))));
        Assert.Equal(
            [(ClientField.Note, "note_too_long")],
            IssuesOf(ClientValidator.Validate(Draft(note: new string('n', 301)))));
    }

    // ---- homónimo (RF-17)

    [Fact]
    public void Homonimo_ignora_mayusculas_y_espacios_exteriores_pero_no_los_interiores()
    {
        Assert.True(Homonyms.HasHomonym("  ana lópez ", ["Ana López"]));
        Assert.True(Homonyms.HasHomonym("NIÑO", ["niño"]));
        Assert.False(Homonyms.HasHomonym("Ana  López", ["Ana López"]));
        Assert.False(Homonyms.HasHomonym("Ana Lopez", ["Ana López"]));
    }

    [Fact]
    public void Un_nombre_vacio_nunca_tiene_homonimos()
    {
        Assert.False(Homonyms.HasHomonym("   ", ["", "Ana"]));
        Assert.False(Homonyms.HasHomonym("Ana", []));
    }

    // ---- paleta de avatares compartida (RF-72)

    [Fact]
    public void La_paleta_coincide_con_la_compartida_en_shared()
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(SharedFile("avatar-palette.json")));
        var root = doc.RootElement;

        Assert.Equal(
            root.GetProperty("characters").EnumerateArray().Select(c => c.GetProperty("id").GetString()!),
            AvatarPalette.CharacterIds);
        Assert.Equal(
            root.GetProperty("skinTones").EnumerateArray()
                .Select(s => (s.GetProperty("id").GetString()!, s.GetProperty("hex").GetString()!)),
            AvatarPalette.SkinTones.Select(s => (s.Id, s.Hex)));
        Assert.Equal(
            root.GetProperty("backgrounds").EnumerateArray()
                .Select(b => (b.GetProperty("id").GetString()!, b.GetProperty("hex").GetString()!)),
            AvatarPalette.Backgrounds.Select(b => (b.Id, b.Hex)));
    }

    [Fact]
    public void Las_1728_combinaciones_son_validas()
    {
        var count = 0;
        foreach (var character in AvatarPalette.CharacterIds)
        {
            foreach (var skin in AvatarPalette.SkinTones)
            {
                foreach (var background in AvatarPalette.Backgrounds)
                {
                    Assert.Empty(AvatarValidator.Validate(character, skin.Id, background.Id));
                    count++;
                }
            }
        }

        Assert.Equal(1728, count);
        Assert.Equal(1728, AvatarPalette.CombinationCount);
    }

    [Theory]
    [InlineData("char-00")]
    [InlineData("char-25")]
    [InlineData("char-1")]
    [InlineData("CHAR-01")]
    [InlineData(" char-01")]
    [InlineData("skin-1")]
    [InlineData("x")]
    public void Un_personaje_fuera_de_la_paleta_se_rechaza(string id)
    {
        var issues = AvatarValidator.Validate(id, "skin-1", "bg-01");

        Assert.Equal([(AvatarComponent.Character, "avatar_character_unknown")], issues.Select(i => (i.Component, i.Code)));
    }

    [Fact]
    public void Un_identificador_de_otro_componente_no_sirve()
    {
        var issues = AvatarValidator.Validate("bg-01", "char-01", "skin-1");

        Assert.Equal(
            [
                (AvatarComponent.Character, "avatar_character_unknown"),
                (AvatarComponent.Skin, "avatar_skin_unknown"),
                (AvatarComponent.Background, "avatar_background_unknown"),
            ],
            issues.Select(i => (i.Component, i.Code)));
    }

    // ---- unidades de venta compartidas (RF-86)

    [Fact]
    public void Las_unidades_coinciden_con_las_compartidas_en_shared()
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(SharedFile("units.json")));
        var root = doc.RootElement;

        Assert.Equal(
            root.GetProperty("units").EnumerateArray().Select(u => u.GetProperty("id").GetString()!),
            Enum.GetValues<SaleUnit>().Select(u => u.Id()));
        Assert.Equal(root.GetProperty("default").GetString(), SaleUnits.Default.Id());
    }

    [Fact]
    public void Una_unidad_fuera_de_la_lista_se_rechaza()
    {
        Assert.True(SaleUnits.IsValidId("pound"));
        Assert.False(SaleUnits.IsValidId("galon"));
        Assert.False(SaleUnits.IsValidId("POUND"));
        Assert.False(SaleUnits.IsValidId(""));
        Assert.False(SaleUnits.IsValidId(null));
        Assert.Equal(SaleUnit.Dozen, SaleUnits.TryFromId("dozen"));
        Assert.Null(SaleUnits.TryFromId("docena"));
    }

    // ---- producto (RF-24, RF-36, RF-86)

    private static List<(ProductField, string)> ProductIssues(
        string name, long price, AmountMode mode = AmountMode.TwoDecimals, string? unit = "unit") =>
        ProductValidator.Validate(name, new Money(price), mode, unit) is InvalidProduct invalid
            ? invalid.Issues.Select(i => (i.Field, i.Code)).ToList()
            : [];

    [Fact]
    public void Un_producto_con_nombre_y_precio_positivo_es_valido()
    {
        Assert.Empty(ProductIssues("Arroz", 2500));
        Assert.Empty(ProductIssues("Fósforo", 1));
        Assert.Empty(ProductIssues("Arroz", 2500, AmountMode.Integer));
    }

    [Fact]
    public void Devuelve_el_nombre_sin_espacios_exteriores_el_precio_y_la_unidad()
    {
        var result = Assert.IsType<ValidProduct>(
            ProductValidator.Validate("  Arroz \t", new Money(2500), AmountMode.TwoDecimals, "pound"));

        Assert.Equal("Arroz", result.Name);
        Assert.Equal(new Money(2500), result.Price);
        Assert.Equal(SaleUnit.Pound, result.Unit);
    }

    [Fact]
    public void Sin_unidad_indicada_usa_la_de_omision()
    {
        var result = Assert.IsType<ValidProduct>(
            ProductValidator.Validate("Arroz", new Money(2500), AmountMode.TwoDecimals, null));

        Assert.Equal(SaleUnit.Unit, result.Unit);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void El_nombre_es_obligatorio(string name) =>
        Assert.Equal([(ProductField.Name, "product_name_required")], ProductIssues(name, 2500));

    [Fact]
    public void El_precio_debe_ser_positivo_y_sin_centavos_con_montos_enteros()
    {
        Assert.Equal([(ProductField.Price, "amount_not_positive")], ProductIssues("Arroz", 0));
        Assert.Equal([(ProductField.Price, "amount_not_positive")], ProductIssues("Arroz", -100));
        Assert.Equal(
            [(ProductField.Price, "amount_not_whole")],
            ProductIssues("Arroz", 1250, AmountMode.Integer));
        Assert.Empty(ProductIssues("Arroz", 1250));
    }

    [Fact]
    public void Una_unidad_fuera_de_la_lista_compartida_se_rechaza_en_el_producto()
    {
        Assert.Equal([(ProductField.Unit, "product_unit_unknown")], ProductIssues("Arroz", 2500, unit: "galon"));
        Assert.Equal([(ProductField.Unit, "product_unit_unknown")], ProductIssues("Arroz", 2500, unit: ""));
        Assert.Empty(ProductIssues("Arroz", 2500, unit: "gallon"));
    }

    [Fact]
    public void Varios_problemas_se_reportan_nombre_precio_y_unidad()
    {
        Assert.Equal(
            [
                (ProductField.Name, "product_name_required"),
                (ProductField.Price, "amount_not_positive"),
                (ProductField.Unit, "product_unit_unknown"),
            ],
            ProductIssues("", 0, unit: "x"));
    }

    private static string SharedFile(string file)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "shared", "vectors", file);
            if (File.Exists(candidate))
            {
                return candidate;
            }
            dir = dir.Parent;
        }
        throw new FileNotFoundException(file);
    }
}
