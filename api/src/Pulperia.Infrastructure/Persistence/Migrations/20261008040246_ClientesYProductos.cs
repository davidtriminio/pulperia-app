using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ClientesYProductos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "clients",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    character_id = table.Column<string>(type: "text", nullable: false),
                    skin_id = table.Column<string>(type: "text", nullable: false),
                    background_id = table.Column<string>(type: "text", nullable: false),
                    phone = table.Column<string>(type: "text", nullable: true),
                    address = table.Column<string>(type: "text", nullable: true),
                    note = table.Column<string>(type: "text", nullable: true),
                    archived = table.Column<bool>(type: "boolean", nullable: false),
                    version = table.Column<int>(type: "integer", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_clients", x => x.id);
                    table.UniqueConstraint("uq_clients_id_business_id", x => new { x.id, x.business_id });
                    table.CheckConstraint("ck_clients_name_required", "btrim(name) <> ''");
                    table.CheckConstraint("ck_clients_note_length", "note IS NULL OR char_length(note) <= 300");
                    table.CheckConstraint("ck_clients_phone_format", "phone IS NULL OR phone ~ '^[2389][0-9]{7}$'");
                    table.CheckConstraint("ck_clients_version", "version >= 1");
                    table.ForeignKey(
                        name: "fk_clients_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_clients_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "products",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    price = table.Column<long>(type: "bigint", nullable: false),
                    unit = table.Column<string>(type: "text", nullable: false),
                    previous_price = table.Column<long>(type: "bigint", nullable: true),
                    price_changed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    archived = table.Column<bool>(type: "boolean", nullable: false),
                    version = table.Column<int>(type: "integer", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_products", x => x.id);
                    table.UniqueConstraint("uq_products_id_business_id", x => new { x.id, x.business_id });
                    table.CheckConstraint("ck_products_name_required", "btrim(name) <> ''");
                    table.CheckConstraint("ck_products_previous_price", "previous_price IS NULL OR previous_price > 0");
                    table.CheckConstraint("ck_products_price", "price > 0");
                    table.CheckConstraint("ck_products_price_history_pair", "(previous_price IS NULL) = (price_changed_at IS NULL)");
                    table.CheckConstraint("ck_products_unit", "unit IN ('unit', 'pound', 'ounce', 'kilo', 'dozen', 'liter', 'gallon', 'box', 'bag', 'pack')");
                    table.CheckConstraint("ck_products_version", "version >= 1");
                    table.ForeignKey(
                        name: "fk_products_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_products_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_clients_business_id",
                table: "clients",
                column: "business_id");

            migrationBuilder.CreateIndex(
                name: "ix_clients_created_by",
                table: "clients",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "ix_products_business_id",
                table: "products",
                column: "business_id");

            migrationBuilder.CreateIndex(
                name: "ix_products_created_by",
                table: "products",
                column: "created_by");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "clients");

            migrationBuilder.DropTable(
                name: "products");
        }
    }
}
