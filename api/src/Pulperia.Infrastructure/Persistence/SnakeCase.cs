using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

namespace Pulperia.Infrastructure.Persistence;

/// <summary>
/// Convención propia de nombres (D-25): tablas, columnas, claves e índices en
/// <c>snake_case</c>, sin añadir ninguna librería.
/// </summary>
internal static class SnakeCase
{
    /// <summary>"LastSeq" pasa a "last_seq"; "UserId" a "user_id".</summary>
    public static string Of(string name)
    {
        var sb = new StringBuilder(name.Length + 4);
        for (var i = 0; i < name.Length; i++)
        {
            var c = name[i];
            if (char.IsUpper(c) && i > 0)
            {
                sb.Append('_');
            }
            sb.Append(char.ToLowerInvariant(c));
        }
        return sb.ToString();
    }

    /// <summary>
    /// Pone en <c>snake_case</c> las columnas de todas las entidades y los nombres de claves
    /// primarias, foráneas e índices que EF generaría en PascalCase. Las tablas y las
    /// restricciones <c>CHECK</c> ya llevan su nombre explícito.
    /// </summary>
    public static void Apply(ModelBuilder modelBuilder)
    {
        foreach (var entity in modelBuilder.Model.GetEntityTypes())
        {
            var table = entity.GetTableName() ?? Of(entity.ClrType.Name);

            foreach (var property in entity.GetProperties())
            {
                property.SetColumnName(Of(property.Name));
            }
            foreach (var key in entity.GetKeys())
            {
                key.SetName(key.IsPrimaryKey()
                    ? $"pk_{table}"
                    : $"uq_{table}_{string.Join('_', key.Properties.Select(p => Of(p.Name)))}");
            }
            foreach (var foreignKey in entity.GetForeignKeys())
            {
                var principal = foreignKey.PrincipalEntityType.GetTableName()
                                ?? Of(foreignKey.PrincipalEntityType.ClrType.Name);
                var columns = string.Join('_', foreignKey.Properties.Select(p => Of(p.Name)));
                foreignKey.SetConstraintName($"fk_{table}_{principal}_{columns}");
            }
            foreach (var index in entity.GetIndexes())
            {
                var columns = string.Join('_', index.Properties.Select(p => Of(p.Name)));
                index.SetDatabaseName($"{(index.IsUnique ? "uq" : "ix")}_{table}_{columns}");
            }
        }
    }
}
