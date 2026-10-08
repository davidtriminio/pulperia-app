using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class FiadosItemsYAbonos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "fiados",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    client_id = table.Column<Guid>(type: "uuid", nullable: false),
                    total = table.Column<long>(type: "bigint", nullable: false),
                    occurred_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    annulled_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    annulled_by = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_fiados", x => x.id);
                    table.UniqueConstraint("uq_fiados_id_business_id", x => new { x.id, x.business_id });
                    table.CheckConstraint("ck_fiados_annulment_pair", "(annulled_at IS NULL) = (annulled_by IS NULL)");
                    table.CheckConstraint("ck_fiados_total", "total > 0");
                    table.ForeignKey(
                        name: "fk_fiados_clients_client_id_business_id",
                        columns: x => new { x.client_id, x.business_id },
                        principalTable: "clients",
                        principalColumns: new[] { "id", "business_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_fiados_users_annulled_by",
                        column: x => x.annulled_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_fiados_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "payments",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    client_id = table.Column<Guid>(type: "uuid", nullable: false),
                    amount = table.Column<long>(type: "bigint", nullable: false),
                    occurred_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    annulled_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    annulled_by = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_payments", x => x.id);
                    table.UniqueConstraint("uq_payments_id_business_id", x => new { x.id, x.business_id });
                    table.CheckConstraint("ck_payments_amount", "amount > 0");
                    table.CheckConstraint("ck_payments_annulment_pair", "(annulled_at IS NULL) = (annulled_by IS NULL)");
                    table.ForeignKey(
                        name: "fk_payments_clients_client_id_business_id",
                        columns: x => new { x.client_id, x.business_id },
                        principalTable: "clients",
                        principalColumns: new[] { "id", "business_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_payments_users_annulled_by",
                        column: x => x.annulled_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_payments_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "fiado_items",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    fiado_id = table.Column<Guid>(type: "uuid", nullable: false),
                    product_id = table.Column<Guid>(type: "uuid", nullable: true),
                    description = table.Column<string>(type: "text", nullable: false),
                    quantity = table.Column<long>(type: "bigint", nullable: false),
                    unit = table.Column<string>(type: "text", nullable: false),
                    unit_price = table.Column<long>(type: "bigint", nullable: false),
                    subtotal = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_fiado_items", x => x.id);
                    table.CheckConstraint("ck_fiado_items_quantity", "quantity > 0");
                    table.CheckConstraint("ck_fiado_items_subtotal", "subtotal > 0");
                    table.CheckConstraint("ck_fiado_items_unit", "unit IN ('unit', 'pound', 'ounce', 'kilo', 'dozen', 'liter', 'gallon', 'box', 'bag', 'pack')");
                    table.CheckConstraint("ck_fiado_items_unit_price", "unit_price > 0");
                    table.ForeignKey(
                        name: "fk_fiado_items_fiados_fiado_id_business_id",
                        columns: x => new { x.fiado_id, x.business_id },
                        principalTable: "fiados",
                        principalColumns: new[] { "id", "business_id" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_fiado_items_products_product_id_business_id",
                        columns: x => new { x.product_id, x.business_id },
                        principalTable: "products",
                        principalColumns: new[] { "id", "business_id" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_fiado_items_fiado_id",
                table: "fiado_items",
                column: "fiado_id");

            migrationBuilder.CreateIndex(
                name: "ix_fiado_items_fiado_id_business_id",
                table: "fiado_items",
                columns: new[] { "fiado_id", "business_id" });

            migrationBuilder.CreateIndex(
                name: "ix_fiado_items_product_id_business_id",
                table: "fiado_items",
                columns: new[] { "product_id", "business_id" });

            migrationBuilder.CreateIndex(
                name: "ix_fiados_annulled_by",
                table: "fiados",
                column: "annulled_by");

            migrationBuilder.CreateIndex(
                name: "ix_fiados_client_id_business_id",
                table: "fiados",
                columns: new[] { "client_id", "business_id" });

            migrationBuilder.CreateIndex(
                name: "ix_fiados_created_by",
                table: "fiados",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "ix_payments_annulled_by",
                table: "payments",
                column: "annulled_by");

            migrationBuilder.CreateIndex(
                name: "ix_payments_client_id_business_id",
                table: "payments",
                columns: new[] { "client_id", "business_id" });

            migrationBuilder.CreateIndex(
                name: "ix_payments_created_by",
                table: "payments",
                column: "created_by");

            // Principio 11 y RF-46: un fiado, un abono o un ítem no se editan ni se eliminan; solo
            // se anulan. Tampoco se borra un cliente ni un producto (RF-20, RF-27). La base lo
            // hace cumplir aunque la aplicación se equivoque.
            migrationBuilder.Sql("""
                CREATE FUNCTION forbid_delete() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN
                    RAISE EXCEPTION 'Los registros de % no se eliminan', TG_TABLE_NAME
                        USING ERRCODE = 'restrict_violation';
                END $$;

                CREATE FUNCTION forbid_update() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN
                    RAISE EXCEPTION 'Los registros de % no se editan', TG_TABLE_NAME
                        USING ERRCODE = 'restrict_violation';
                END $$;

                CREATE FUNCTION allow_only_annulment() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN
                    IF (to_jsonb(NEW) - 'annulled_at' - 'annulled_by')
                       IS DISTINCT FROM (to_jsonb(OLD) - 'annulled_at' - 'annulled_by') THEN
                        RAISE EXCEPTION 'Un movimiento de % no se edita: solo se anula', TG_TABLE_NAME
                            USING ERRCODE = 'restrict_violation';
                    END IF;
                    IF OLD.annulled_at IS NOT NULL
                       AND (NEW.annulled_at IS DISTINCT FROM OLD.annulled_at
                            OR NEW.annulled_by IS DISTINCT FROM OLD.annulled_by) THEN
                        RAISE EXCEPTION 'Un movimiento anulado no cambia'
                            USING ERRCODE = 'restrict_violation';
                    END IF;
                    RETURN NEW;
                END $$;

                CREATE TRIGGER trg_fiados_no_delete BEFORE DELETE ON fiados
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                CREATE TRIGGER trg_payments_no_delete BEFORE DELETE ON payments
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                CREATE TRIGGER trg_fiado_items_no_delete BEFORE DELETE ON fiado_items
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                CREATE TRIGGER trg_clients_no_delete BEFORE DELETE ON clients
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                CREATE TRIGGER trg_products_no_delete BEFORE DELETE ON products
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();

                CREATE TRIGGER trg_fiados_only_annul BEFORE UPDATE ON fiados
                    FOR EACH ROW EXECUTE FUNCTION allow_only_annulment();
                CREATE TRIGGER trg_payments_only_annul BEFORE UPDATE ON payments
                    FOR EACH ROW EXECUTE FUNCTION allow_only_annulment();
                CREATE TRIGGER trg_fiado_items_no_update BEFORE UPDATE ON fiado_items
                    FOR EACH ROW EXECUTE FUNCTION forbid_update();
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DROP TRIGGER trg_products_no_delete ON products;
                DROP TRIGGER trg_clients_no_delete ON clients;
                DROP FUNCTION allow_only_annulment() CASCADE;
                DROP FUNCTION forbid_update() CASCADE;
                DROP FUNCTION forbid_delete() CASCADE;
                """);

            migrationBuilder.DropTable(
                name: "fiado_items");

            migrationBuilder.DropTable(
                name: "payments");

            migrationBuilder.DropTable(
                name: "fiados");
        }
    }
}
