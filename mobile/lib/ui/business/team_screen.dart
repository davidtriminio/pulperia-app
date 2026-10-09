import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/remote/models.dart';
import '../../domain/access/access.dart';
import '../../domain/account/account_validation.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../auth/auth_widgets.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';

/// El equipo del negocio y sus invitaciones pendientes.
typedef TeamOverview = ({
  List<TeamMember> members,
  List<BusinessInvitation> invitations,
});

/// Lo trae del servidor cada vez que se abre la pantalla o se cambia algo:
/// el equipo es en línea y el servidor es la única autoridad (D-3).
final teamOverviewProvider = FutureProvider.autoDispose<TeamOverview>(
  retry: (_, _) => null,
  (ref) async {
    final service = ref.watch(managementServiceProvider);
    final businessId = ref.watch(activeBusinessIdProvider);
    final members = await service.team(businessId);
    final invitations = await service.invitations(businessId);
    return (
      members: members,
      invitations: [
        for (final i in invitations)
          if (i.status == InvitationStatus.pending) i,
      ],
    );
  },
);

/// Equipo (RF-10, RF-11, RF-69 a RF-71): miembros, invitar, cancelar
/// invitaciones, promover y quitar. Solo el dueño (RF-13).
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String? _actionError;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _actionError = null);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _actionError = errorMessage(e));
      }
    }
    ref.invalidate(teamOverviewProvider);
  }

  Future<void> _promote(TeamMember member) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.verified_user_outlined,
      title: Strings.promoteConfirmTitle,
      body: Strings.promoteConfirmBody(member.email),
      confirmLabel: Strings.promoteAction,
      cancelLabel: Strings.cancel,
      confirmKey: const ValueKey('confirm-yes'),
      cancelKey: const ValueKey('confirm-no'),
    );
    if (!ok) {
      return;
    }
    await _run(
      () => ref
          .read(managementServiceProvider)
          .promote(ref.read(activeBusinessIdProvider), member.userId),
    );
  }

  Future<void> _remove(TeamMember member) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.person_remove_outlined,
      title: Strings.removeConfirmTitle,
      body: Strings.removeConfirmBody(member.email),
      confirmLabel: Strings.removeAction,
      cancelLabel: Strings.cancel,
      confirmKey: const ValueKey('confirm-yes'),
      cancelKey: const ValueKey('confirm-no'),
    );
    if (!ok) {
      return;
    }
    await _run(
      () => ref
          .read(managementServiceProvider)
          .remove(ref.read(activeBusinessIdProvider), member.userId),
    );
  }

  Future<void> _cancelInvitation(BusinessInvitation invitation) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.mail_lock_outlined,
      title: Strings.cancelInvitationTitle,
      body: Strings.cancelInvitationBody(invitation.email),
      confirmLabel: Strings.cancelInvitation,
      cancelLabel: Strings.keepInvitation,
      confirmKey: const ValueKey('confirm-yes'),
      cancelKey: const ValueKey('confirm-no'),
    );
    if (!ok) {
      return;
    }
    await _run(
      () => ref
          .read(managementServiceProvider)
          .cancelInvitation(ref.read(activeBusinessIdProvider), invitation.id),
    );
  }

  Future<void> _invite() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (sent == true) {
      ref.invalidate(teamOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(Strings.inviteSent)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(teamOverviewProvider);
    final me = ref.watch(activeUserProvider).id;
    return Scaffold(
      key: const ValueKey('team-screen'),
      appBar: AppBar(title: const Text(Strings.teamTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('team-invite'),
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text(Strings.inviteAction),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorBanner(errorMessage(e)),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('team-retry'),
                onPressed: () => ref.invalidate(teamOverviewProvider),
                child: const Text(Strings.retry),
              ),
            ],
          ),
        ),
        data: (data) {
          final owners = data.members.where((m) => m.role == Role.owner).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (_actionError != null) ...[
                KeyedSubtree(
                  key: const ValueKey('team-error'),
                  child: ErrorBanner(_actionError!),
                ),
                const SizedBox(height: 12),
              ],
              _SectionTitle(Strings.teamMembers),
              for (final member in data.members)
                _MemberTile(
                  member: member,
                  isMe: member.userId == me,
                  // El único dueño no se puede quitar ni degradar (RF-71);
                  // tampoco se ofrece quitarse a uno mismo.
                  canManage:
                      member.userId != me &&
                      !(member.role == Role.owner && owners <= 1),
                  onPromote: () => _promote(member),
                  onRemove: () => _remove(member),
                ),
              const SizedBox(height: 16),
              _SectionTitle(Strings.teamInvitations),
              if (data.invitations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    Strings.noInvitations,
                    key: const ValueKey('no-invitations'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              for (final invitation in data.invitations)
                _InvitationTile(
                  invitation: invitation,
                  onCancel: () => _cancelInvitation(invitation),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onPromote,
    required this.onRemove,
  });

  final TeamMember member;
  final bool isMe;
  final bool canManage;
  final VoidCallback onPromote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final owner = member.role == Role.owner;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: ValueKey('member-${member.userId}'),
        leading: CircleAvatar(
          backgroundColor: AppColors.turquoise.withValues(alpha: 0.2),
          child: Text(
            member.email.isEmpty ? '?' : member.email[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(member.email, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Text(
              owner ? Strings.roleOwner : Strings.roleEmployee,
              key: ValueKey('member-role-${member.userId}'),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              const Text(Strings.youMarker),
            ],
          ],
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                key: ValueKey('member-menu-${member.userId}'),
                onSelected: (value) =>
                    value == 'promote' ? onPromote() : onRemove(),
                itemBuilder: (_) => [
                  if (!owner)
                    PopupMenuItem(
                      key: ValueKey('member-promote-${member.userId}'),
                      value: 'promote',
                      child: const Text(Strings.promoteAction),
                    ),
                  PopupMenuItem(
                    key: ValueKey('member-remove-${member.userId}'),
                    value: 'remove',
                    child: const Text(Strings.removeAction),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation, required this.onCancel});

  final BusinessInvitation invitation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      key: ValueKey('invitation-${invitation.id}'),
      leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
      title: Text(
        invitation.email ?? Strings.codeOnlyInvitation,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: const Text(Strings.invitationPending),
      trailing: IconButton(
        key: ValueKey('invitation-cancel-${invitation.id}'),
        tooltip: Strings.cancelInvitation,
        icon: const Icon(Icons.close),
        onPressed: onCancel,
      ),
    ),
  );
}

/// Pide el correo de la persona e invita (RF-10).
class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _email = TextEditingController();
  AccountError? _emailError;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    final emailError = validateEmail(_email.text);
    setState(() {
      _emailError = emailError;
      _error = null;
    });
    if (emailError != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(managementServiceProvider)
          .invite(
            ref.read(activeBusinessIdProvider),
            email: _email.text.trim().toLowerCase(),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(Strings.inviteTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('invite-email'),
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            inputFormatters: [LengthLimitingTextInputFormatter(254)],
            decoration: InputDecoration(
              labelText: Strings.fieldEmail,
              error: fieldError(
                _emailError == null ? null : accountErrorText(_emailError!),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const ValueKey('invite-error'),
              child: ErrorBanner(_error!),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('invite-cancel'),
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text(Strings.cancel),
      ),
      FilledButton(
        key: const ValueKey('invite-send'),
        style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
        onPressed: _busy ? null : _send,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(Strings.inviteSend),
      ),
    ],
  );
}
