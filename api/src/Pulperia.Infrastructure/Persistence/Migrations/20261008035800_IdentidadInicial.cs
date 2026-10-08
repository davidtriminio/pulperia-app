using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class IdentidadInicial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "businesses",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    amount_mode = table.Column<string>(type: "text", nullable: false),
                    quantity_mode = table.Column<string>(type: "text", nullable: false),
                    last_seq = table.Column<long>(type: "bigint", nullable: false, defaultValue: 0L),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_businesses", x => x.id);
                    table.CheckConstraint("ck_businesses_amount_mode", "amount_mode IN ('integer', 'two_decimals')");
                    table.CheckConstraint("ck_businesses_last_seq", "last_seq >= 0");
                    table.CheckConstraint("ck_businesses_name_required", "btrim(name) <> ''");
                    table.CheckConstraint("ck_businesses_quantity_mode", "quantity_mode IN ('integer', 'fractional')");
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    password_hash = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_users", x => x.id);
                    table.CheckConstraint("ck_users_email_normalized", "email = lower(btrim(email)) AND btrim(email) <> ''");
                });

            migrationBuilder.CreateTable(
                name: "invitations",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    email = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_invitations", x => x.id);
                    table.CheckConstraint("ck_invitations_email_normalized", "email = lower(btrim(email)) AND btrim(email) <> ''");
                    table.CheckConstraint("ck_invitations_status", "status IN ('pending', 'accepted', 'rejected', 'cancelled')");
                    table.ForeignKey(
                        name: "fk_invitations_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_invitations_users_created_by",
                        column: x => x.created_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "memberships",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_id = table.Column<Guid>(type: "uuid", nullable: false),
                    role = table.Column<string>(type: "text", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    removed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    final_sync_used = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_memberships", x => new { x.user_id, x.business_id });
                    table.CheckConstraint("ck_memberships_removed_at", "status <> 'removed' OR removed_at IS NOT NULL");
                    table.CheckConstraint("ck_memberships_role", "role IN ('owner', 'employee')");
                    table.CheckConstraint("ck_memberships_status", "status IN ('active', 'removed')");
                    table.ForeignKey(
                        name: "fk_memberships_businesses_business_id",
                        column: x => x.business_id,
                        principalTable: "businesses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_memberships_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_invitations_business_id",
                table: "invitations",
                column: "business_id");

            migrationBuilder.CreateIndex(
                name: "ix_invitations_created_by",
                table: "invitations",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "ix_invitations_email_status",
                table: "invitations",
                columns: new[] { "email", "status" });

            migrationBuilder.CreateIndex(
                name: "ix_memberships_business_id",
                table: "memberships",
                column: "business_id");

            migrationBuilder.CreateIndex(
                name: "uq_users_email",
                table: "users",
                column: "email",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "invitations");

            migrationBuilder.DropTable(
                name: "memberships");

            migrationBuilder.DropTable(
                name: "businesses");

            migrationBuilder.DropTable(
                name: "users");
        }
    }
}
