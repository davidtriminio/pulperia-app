using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SuperAdministrador : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_admin_audit_action",
                table: "admin_audit");

            migrationBuilder.AddColumn<bool>(
                name: "is_super_admin",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "suspended_at",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "suspension_reason",
                table: "users",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "status",
                table: "businesses",
                type: "text",
                nullable: false,
                defaultValue: "active");

            migrationBuilder.AddColumn<string>(
                name: "status_reason",
                table: "businesses",
                type: "text",
                nullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "target_user_id",
                table: "admin_audit",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<string>(
                name: "detail",
                table: "admin_audit",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "target_business_id",
                table: "admin_audit",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_suspension",
                table: "users",
                sql: "(suspended_at IS NULL AND suspension_reason IS NULL) OR (suspended_at IS NOT NULL AND coalesce(btrim(suspension_reason), '') <> '')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_businesses_status",
                table: "businesses",
                sql: "status IN ('pending', 'active', 'suspended')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_businesses_status_reason",
                table: "businesses",
                sql: "status <> 'suspended' OR coalesce(btrim(status_reason), '') <> ''");

            migrationBuilder.CreateIndex(
                name: "ix_admin_audit_target_business_id",
                table: "admin_audit",
                column: "target_business_id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_admin_audit_action",
                table: "admin_audit",
                sql: "action IN ('reset_password', 'grant_superadmin', 'revoke_superadmin', 'suspend_business', 'reactivate_business', 'activate_business', 'suspend_account', 'reactivate_account')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_admin_audit_reason",
                table: "admin_audit",
                sql: "action NOT IN ('suspend_business', 'suspend_account') OR coalesce(btrim(detail), '') <> ''");

            migrationBuilder.AddCheckConstraint(
                name: "ck_admin_audit_target",
                table: "admin_audit",
                sql: "target_user_id IS NOT NULL OR target_business_id IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "fk_admin_audit_businesses_target_business_id",
                table: "admin_audit",
                column: "target_business_id",
                principalTable: "businesses",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);

            // La plataforma siempre debe tener a quien la administre (RF-95): la base misma no deja
            // retirar la marca al último super administrador. El candado serializa dos retiros
            // simultáneos, para que no se quiten los dos a la vez.
            migrationBuilder.Sql("""
                CREATE FUNCTION keep_last_super_admin() RETURNS trigger AS $$
                BEGIN
                    IF OLD.is_super_admin AND NOT NEW.is_super_admin THEN
                        PERFORM pg_advisory_xact_lock(7340186);
                        IF NOT EXISTS (SELECT 1 FROM users WHERE is_super_admin AND id <> OLD.id) THEN
                            RAISE EXCEPTION 'last_super_admin' USING ERRCODE = 'P0001';
                        END IF;
                    END IF;
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;

                CREATE TRIGGER trg_users_keep_last_super_admin BEFORE UPDATE OF is_super_admin ON users
                    FOR EACH ROW EXECUTE FUNCTION keep_last_super_admin();
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DROP TRIGGER trg_users_keep_last_super_admin ON users;
                DROP FUNCTION keep_last_super_admin();
                """);

            migrationBuilder.DropForeignKey(
                name: "fk_admin_audit_businesses_target_business_id",
                table: "admin_audit");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_suspension",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_businesses_status",
                table: "businesses");

            migrationBuilder.DropCheckConstraint(
                name: "ck_businesses_status_reason",
                table: "businesses");

            migrationBuilder.DropIndex(
                name: "ix_admin_audit_target_business_id",
                table: "admin_audit");

            migrationBuilder.DropCheckConstraint(
                name: "ck_admin_audit_action",
                table: "admin_audit");

            migrationBuilder.DropCheckConstraint(
                name: "ck_admin_audit_reason",
                table: "admin_audit");

            migrationBuilder.DropCheckConstraint(
                name: "ck_admin_audit_target",
                table: "admin_audit");

            migrationBuilder.DropColumn(
                name: "is_super_admin",
                table: "users");

            migrationBuilder.DropColumn(
                name: "suspended_at",
                table: "users");

            migrationBuilder.DropColumn(
                name: "suspension_reason",
                table: "users");

            migrationBuilder.DropColumn(
                name: "status",
                table: "businesses");

            migrationBuilder.DropColumn(
                name: "status_reason",
                table: "businesses");

            migrationBuilder.DropColumn(
                name: "detail",
                table: "admin_audit");

            migrationBuilder.DropColumn(
                name: "target_business_id",
                table: "admin_audit");

            migrationBuilder.AlterColumn<Guid>(
                name: "target_user_id",
                table: "admin_audit",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_admin_audit_action",
                table: "admin_audit",
                sql: "action IN ('reset_password')");
        }
    }
}
