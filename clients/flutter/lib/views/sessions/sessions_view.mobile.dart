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

class SessionsViewMobile extends StatefulWidget {
  final void Function(int) onSwitchTab;

  const SessionsViewMobile({required this.onSwitchTab, super.key});

  @override
  State<SessionsViewMobile> createState() => _SessionsViewMobileState();
}

class _SessionsViewMobileState extends State<SessionsViewMobile>
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
    return Column(
      children: [
        _SessionsHeader(statusTop: MediaQuery.of(context).padding.top),
        Expanded(
          child: Selector<SessionsViewModel, SessionsState>(
            selector: (_, vm) => vm.state,
            builder: (context, state, _) => switch (state) {
              SessionsState.idle || SessionsState.loading => const _LoadingBody(),
              SessionsState.error => VailErrorScreen(
                  message: context.read<SessionsViewModel>().errorMessage,
                  onRetry: () => context.read<SessionsViewModel>().load(),
                ),
              SessionsState.loaded => _SessionsList(
                  onSwitchTab: widget.onSwitchTab,
                ),
            },
          ),
        ),
      ],
    );
  }
}

class _SessionsHeader extends StatelessWidget {
  final double statusTop;
  const _SessionsHeader({required this.statusTop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: statusTop + VailTheme.sm,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.sm,
      ),
      decoration: BoxDecoration(
        color: VailTheme.background.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: VailTheme.ghostBorder)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, color: VailTheme.primary, size: 18),
              const SizedBox(width: VailTheme.xs + 2),
              Text('History', style: VailTheme.heading.copyWith(fontSize: 18)),
            ],
          ),
          const Spacer(),
          Icon(Icons.search_rounded,
              color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
        ],
      ),
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

    return RefreshIndicator(
      color: VailTheme.primary,
      backgroundColor: VailTheme.surfaceContainer,
      onRefresh: () => context.read<SessionsViewModel>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: VailTheme.md, horizontal: VailTheme.sm),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _SessionTile(
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
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({required this.session, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VailTheme.sm, vertical: VailTheme.xs + 1),
      child: Dismissible(
        key: ValueKey(session.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: VailTheme.lg),
          margin: const EdgeInsets.symmetric(vertical: VailTheme.xs),
          decoration: BoxDecoration(
            color: VailTheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(VailTheme.radiusMd),
            border: Border.all(color: VailTheme.error.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: VailTheme.error, size: 18),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(VailTheme.md),
            decoration: BoxDecoration(
              color: VailTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(VailTheme.radiusMd),
              border: Border.all(color: VailTheme.ghostBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar: leaf icon in a small circle
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
                const SizedBox(width: VailTheme.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayTitle,
                        style: VailTheme.label.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: VailTheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: VailTheme.xs),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: VailTheme.primaryContainer.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                              border: Border.all(color: VailTheme.primary.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 8, color: VailTheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  '${session.messageCount}',
                                  style: VailTheme.micro.copyWith(color: VailTheme.primary, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: VailTheme.xs),
                          Text(
                            _relativeTime(session.updatedAt),
                            style: VailTheme.micro.copyWith(color: VailTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VailTheme.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: VailTheme.onSurfaceVariant.withValues(alpha: 0.25),
                  size: 16,
                ),
              ],
            ),
          ),
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
  Widget build(BuildContext context) => Center(child: CircularProgressIndicator(color: VailTheme.primary.withValues(alpha: 0.7), strokeWidth: 1.5));
}
