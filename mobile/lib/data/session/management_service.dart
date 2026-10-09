import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../remote/api_client.dart';
import '../remote/models.dart';
import 'session_service.dart';

/// Ajustes del negocio, equipo e invitaciones. Todo esto es en línea y el
/// servidor es la única autoridad (D-3): nada pasa por la cola ni por la base
/// local. Cada llamada usa el token vigente y los errores (sin conexión, sesión
/// caducada, rechazos de la API) suben a quien llama.
class ManagementService {
  ManagementService({required this.sessions, required this.api});

  final SessionService sessions;
  final PulperiaApi api;

  Future<BusinessSettings> updateSettings(
    String businessId, {
    String? name,
    AmountMode? amountMode,
    QuantityMode? quantityMode,
  }) async => api.updateSettings(
    await sessions.accessToken(),
    businessId,
    name: name,
    amountMode: amountMode,
    quantityMode: quantityMode,
  );

  Future<List<TeamMember>> team(String businessId) async =>
      api.listTeam(await sessions.accessToken(), businessId);

  Future<void> promote(String businessId, String userId) async =>
      api.promote(await sessions.accessToken(), businessId, userId);

  Future<void> remove(String businessId, String userId) async =>
      api.removeMember(await sessions.accessToken(), businessId, userId);

  Future<List<BusinessInvitation>> invitations(String businessId) async =>
      api.listBusinessInvitations(await sessions.accessToken(), businessId);

  Future<BusinessInvitation> invite(String businessId, {String? email}) async =>
      api.invite(await sessions.accessToken(), businessId, email: email);

  Future<void> cancelInvitation(String businessId, String invitationId) async =>
      api.cancelInvitation(
        await sessions.accessToken(),
        businessId,
        invitationId,
      );

  Future<List<InvitationOffer>> receivedInvitations() async =>
      api.listInvitations(await sessions.accessToken());

  Future<RemoteBusiness> accept(String invitationId) async =>
      api.acceptInvitation(await sessions.accessToken(), invitationId);

  Future<void> reject(String invitationId) async =>
      api.rejectInvitation(await sessions.accessToken(), invitationId);

  Future<RemoteBusiness> redeem(String code) async =>
      api.redeemInvitationCode(await sessions.accessToken(), code);
}
