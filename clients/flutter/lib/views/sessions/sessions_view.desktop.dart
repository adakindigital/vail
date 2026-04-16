import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_error_screen.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/services/vail_client.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';
import 'package:vail_app/views/sessions/widgets/sessions_empty_state.dart';

class SessionsViewDesktop extends StatefulWidget {
  final void Function(int) onSwitchTab;

  const SessionsViewDesktop({required this.onSwitchTab, super.key});

  @override
  State<SessionsViewDesktop> createState() => _SessionsViewDesktopState();
}

class _SessionsViewDesktopState extends State<SessionsViewDesktop>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Selector<SessionsViewModel, SessionsState>(
      selector: (_, vm) => vm.state,
      builder: (context, state, _) => switch (state) {
        SessionsState.idle || SessionsState.loading => const _LoadingBody(),
        SessionsState.error => VailErrorScreen(
            message: context.read<SessionsViewModel>().errorMessage,
            onRetry: () => context.read<SessionsViewModel>().load(),
          ),
        SessionsState.loaded => _SessionsList(onSwitchTab: widget.onSwitchTab),
      },
    );
  }
}

class _SessionsList extends StatelessWidget {
  final void Function(int) onSwitchTab;
  const _SessionsList({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionsViewModel>().sessions;
    if (sessions.isEmpty) return SessionsEmptyState(onStartChat: () => onSwitchTab(0));

    return Column(
      children: [
        _ListHeader(onRefresh: () => context.read<SessionsViewModel>().load()),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(VailTheme.lg),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: VailTheme.sm),
            itemBuilder: (context, index) => _SessionCard(
              session: sessions[index],
              onTap: () async {
                final config = GetIt.I<AppConfig>();
                final client = VailClient(endpoint: config.endpoint, apiKey: config.apiKey, sessionId: '');
                try {
                  final messages = await client.getSessionMessages(sessions[index].id);
                  if (context.mounted) {
                    context.read<ChatViewModel>().loadSession(sessions[index].id, messages);
                    onSwitchTab(0);
                  }
                } catch (_) {}
              },
              onDelete: () => context.read<SessionsViewModel>().deleteSession(sessions[index].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _ListHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.lg, vertical: VailTheme.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VailTheme.ghostBorder))),
      child: Row(
        children: [
          Text('CONVERSATIONS', style: VailTheme.caption.copyWith(letterSpacing: 1.2, fontSize: 10)),
          const Spacer(),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh_rounded, color: VailTheme.onSurfaceVariant, size: 16),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({required this.session, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VailTheme.md),
        decoration: BoxDecoration(
          color: VailTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
          border: Border.all(color: VailTheme.ghostBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.eco_rounded, color: VailTheme.primary, size: 16),
            ),
            const SizedBox(width: VailTheme.md),
            // Title
            Expanded(
              flex: 5,
              child: Text(
                session.displayTitle,
                style: VailTheme.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: VailTheme.lg),
            // Message count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                border: Border.all(color: VailTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 9, color: VailTheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${session.messageCount}',
                    style: VailTheme.micro.copyWith(color: VailTheme.primary, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: VailTheme.md),
            // Relative time
            SizedBox(
              width: 80,
              child: Text(
                _relativeTime(session.updatedAt),
                style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: VailTheme.md),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded, color: VailTheme.textMuted, size: 15),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: VailTheme.primary, strokeWidth: 1.5),
  );
}
