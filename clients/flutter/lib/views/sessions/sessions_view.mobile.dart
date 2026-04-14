import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/services/vail_client.dart';
import 'package:vail_app/views/chat/chat_viewmodel.dart';
import 'package:vail_app/views/sessions/sessions_viewmodel.dart';

/// Mobile sessions (history) UI — list of past conversations with
/// pull-to-refresh and swipe-to-delete.
///
/// Rendered by [SessionsView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [SessionsView].
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
              SessionsState.error => _ErrorBody(
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

// ── Header ────────────────────────────────────────────────────────────────────

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

// ── List ──────────────────────────────────────────────────────────────────────

class _SessionsList extends StatelessWidget {
  final void Function(int) onSwitchTab;

  const _SessionsList({required this.onSwitchTab});

  Future<void> _openSession(BuildContext context, String sessionId) async {
    final config = GetIt.I<AppConfig>();
    final client = VailClient(
      endpoint: config.endpoint,
      apiKey: config.apiKey,
      sessionId: '',
    );
    try {
      final messages = await client.getSessionMessages(sessionId);
      if (!context.mounted) return;
      context.read<ChatViewModel>().loadSession(sessionId, messages);
    } catch (_) {}
    if (context.mounted) onSwitchTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionsViewModel>().sessions;
    if (sessions.isEmpty) return const _EmptyState();

    return RefreshIndicator(
      color: VailTheme.primary,
      backgroundColor: VailTheme.surfaceContainer,
      onRefresh: () => context.read<SessionsViewModel>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          vertical: VailTheme.md,
          horizontal: VailTheme.sm,
        ),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _SessionTile(
          session: sessions[index],
          onTap: () => _openSession(context, sessions[index].id),
          onDelete: () =>
              context.read<SessionsViewModel>().deleteSession(sessions[index].id),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: VailTheme.xl),
        decoration: BoxDecoration(
          color: VailTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: VailTheme.error, size: 20),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayTitle,
                      style: VailTheme.label.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: VailTheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VailTheme.xs),
                    Row(
                      children: [
                        Text(
                          _relativeTime(session.updatedAt),
                          style: VailTheme.bodySmall.copyWith(fontSize: 11),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: VailTheme.xs + 2),
                          child: Text('·',
                              style: VailTheme.bodySmall.copyWith(
                                color: VailTheme.textMuted,
                              )),
                        ),
                        Text(
                          '${session.messageCount} messages',
                          style: VailTheme.bodySmall.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: VailTheme.onSurfaceVariant.withValues(alpha: 0.3),
                  size: 18),
            ],
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

// ── States ────────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: VailTheme.primary.withValues(alpha: 0.7),
        strokeWidth: 1.5,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VailTheme.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VailTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: VailTheme.error, size: 24),
            ),
            const SizedBox(height: VailTheme.lg),
            Text(
              'Signal interrupted',
              style: VailTheme.subheading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.sm),
            Text(
              message,
              style: VailTheme.bodySmall.copyWith(
                  color: VailTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VailTheme.xl),
            VailButton.primary(label: 'Retry', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VailTheme.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VailTheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: VailTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: VailTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: VailTheme.lg),
            Text('No conversations yet', style: VailTheme.subheading),
            const SizedBox(height: VailTheme.sm),
            Text(
              'Start a chat to see it here.',
              style: VailTheme.bodySmall.copyWith(
                  color: VailTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
