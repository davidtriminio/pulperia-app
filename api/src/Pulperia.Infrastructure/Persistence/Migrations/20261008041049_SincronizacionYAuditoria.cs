using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SincronizacionYAuditoria : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "admin_audit",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    action = table.Column<string>(type: "text", nullable: false),
                    target_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    performed_by = table.Column<string>(type: "text", nullable: false),
                    performed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_admin_audit", x => x.id);
                    table.CheckConstraint("ck_admin_audit_action", "action IN ('reset_password')");
                    table.CheckConstraint("ck_admin_audit_performed_by", "btrim(performed_by) <> ''");
                    table.ForeignKey(
                        name: "fk_admin_audit_users_target_user_id",
                        column: x => x.target_user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "change_log",
                columns: table => new
                {
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    seq = table.Column<long>(type: "bigint", nullable: false),
                    entity_type = table.Column<string>(type: "text", nullable: false),
                    entity_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_change_log", x => new { x.business_id, x.seq });
                    table.CheckConstraint("ck_change_log_entity_type", "entity_type IN ('client', 'product', 'fiado', 'payment')");
                    table.CheckConstraint("ck_change_log_seq", "seq > 0");
                    table.ForeignKey(
                        name: "fk_change_log_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "processed_ops",
                columns: table => new
                {
                    op_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    result = table.Column<string>(type: "text", nullable: false),
                    processed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_processed_ops", x => x.op_id);
                    table.CheckConstraint("ck_processed_ops_result", "btrim(result) <> ''");
                    table.ForeignKey(
                        name: "fk_processed_ops_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_admin_audit_target_user_id",
                table: "admin_audit",
                column: "target_user_id");

            migrationBuilder.CreateIndex(
                name: "ix_processed_ops_business_id",
                table: "processed_ops",
                column: "business_id");

            // Solo se agrega: el registro de cambios y la auditoría no se editan ni se borran, y el
            // resultado de una operación procesada no cambia (RF-53, RF-81). Usa las funciones
            // creadas en la migración de fiados.
            migrationBuilder.Sql("""
                CREATE TRIGGER trg_change_log_no_update BEFORE UPDATE ON change_log
                    FOR EACH ROW EXECUTE FUNCTION forbid_update();
                CREATE TRIGGER trg_change_log_no_delete BEFORE DELETE ON change_log
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                CREATE TRIGGER trg_processed_ops_no_update BEFORE UPDATE ON processed_ops
                    FOR EACH ROW EXECUTE FUNCTION forbid_update();
                CREATE TRIGGER trg_admin_audit_no_update BEFORE UPDATE ON admin_audit
                    FOR EACH ROW EXECUTE FUNCTION forbid_update();
                CREATE TRIGGER trg_admin_audit_no_delete BEFORE DELETE ON admin_audit
                    FOR EACH ROW EXECUTE FUNCTION forbid_delete();
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DROP TRIGGER trg_admin_audit_no_delete ON admin_audit;
                DROP TRIGGER trg_admin_audit_no_update ON admin_audit;
                DROP TRIGGER trg_processed_ops_no_update ON processed_ops;
                DROP TRIGGER trg_change_log_no_delete ON change_log;
                DROP TRIGGER trg_change_log_no_update ON change_log;
                """);

            migrationBuilder.DropTable(
                name: "admin_audit");

            migrationBuilder.DropTable(
                name: "change_log");

            migrationBuilder.DropTable(
                name: "processed_ops");
        }
    }
}
