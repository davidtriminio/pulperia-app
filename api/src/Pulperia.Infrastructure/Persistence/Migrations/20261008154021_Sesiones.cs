using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Sesiones : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "sessions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    access_token_hash = table.Column<string>(type: "text", nullable: false),
                    access_expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    refresh_token_hash = table.Column<string>(type: "text", nullable: false),
                    refresh_expires_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_sessions", x => x.id);
                    table.ForeignKey(
                        name: "fk_sessions_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_sessions_user_id",
                table: "sessions",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "uq_sessions_access_token_hash",
                table: "sessions",
                column: "access_token_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "uq_sessions_refresh_token_hash",
                table: "sessions",
                column: "refresh_token_hash",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "sessions");
        }
    }
}
