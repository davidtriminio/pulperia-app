using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pulperia.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CodigoDeInvitacion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "ck_invitations_email_normalized",
                table: "invitations");

            migrationBuilder.AlterColumn<string>(
                name: "email",
                table: "invitations",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.AddColumn<string>(
                name: "code",
                table: "invitations",
                type: "text",
                nullable: false,
                defaultValue: "");

            // Las invitaciones que ya existían reciben un código propio (derivado de su id) antes de
            // exigir que sea único; solo se activan por correo, porque no tienen el alfabeto del código.
            migrationBuilder.Sql("UPDATE invitations SET code = upper(substr(md5(id::text), 1, 8))");

            migrationBuilder.CreateIndex(
                name: "uq_invitations_code",
                table: "invitations",
                column: "code",
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_invitations_code_format",
                table: "invitations",
                sql: "code ~ '^[A-Z0-9]{8}$'");

            migrationBuilder.AddCheckConstraint(
                name: "ck_invitations_email_normalized",
                table: "invitations",
                sql: "email IS NULL OR (email = lower(btrim(email)) AND btrim(email) <> '')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "uq_invitations_code",
                table: "invitations");

            migrationBuilder.DropCheckConstraint(
                name: "ck_invitations_code_format",
                table: "invitations");

            migrationBuilder.DropCheckConstraint(
                name: "ck_invitations_email_normalized",
                table: "invitations");

            migrationBuilder.DropColumn(
                name: "code",
                table: "invitations");

            // Sin correo no hay forma de representar la invitación en el esquema anterior.
            migrationBuilder.Sql("DELETE FROM invitations WHERE email IS NULL");

            migrationBuilder.AlterColumn<string>(
                name: "email",
                table: "invitations",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_invitations_email_normalized",
                table: "invitations",
                sql: "email = lower(btrim(email)) AND btrim(email) <> ''");
        }
    }
}
