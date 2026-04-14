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
        top: statusTop + VailTheme.lg,
        left: VailTheme.lg,
        right: VailTheme.lg,
        bottom: VailTheme.lg,
      ),
      decoration: const BoxDecoration(
        color: VailTheme.background,
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('Sessions', style: VailTheme.heading)),
          Icon(Icons.search_rounded, color: VailTheme.textSecondary, size: 20),
          SizedBox(width: VailTheme.md),
          Icon(Icons.tune_rounded, color: VailTheme.textSecondary, size: 20),
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
      color: VailTheme.accent,
      backgroundColor: VailTheme.surface,
      onRefresh: () => context.read<SessionsViewModel>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: VailTheme.sm),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: VailTheme.lg,
          endIndent: VailTheme.lg,
        ),
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
        color: VailTheme.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline_rounded,
            color: VailTheme.error, size: 20),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.lg,
            vertical: VailTheme.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayTitle,
                      style: VailTheme.sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: VailTheme.xs),
                    Row(
                      children: [
                        Text(_relativeTime(session.updatedAt),
                            style: VailTheme.bodySmall),
                        const SizedBox(width: VailTheme.sm),
                        Text('·',
                            style: VailTheme.bodySmall
                                .copyWith(color: VailTheme.textMuted)),
                        const SizedBox(width: VailTheme.sm),
                        Text(
                          '${session.messageCount} messages',
                          style: VailTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: VailTheme.textMuted, size: 18),
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
    return const Center(
      child: CircularProgressIndicator(
          color: VailTheme.accent, strokeWidth: 1.5),
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
            const Icon(Icons.wifi_off_rounded,
                color: VailTheme.textMuted, size: 32),
            const SizedBox(height: VailTheme.md),
            Text(message,
                style: VailTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: VailTheme.xl),
            VailButton.primary(label: 'RETRY', onTap: onRetry),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded,
              color: VailTheme.textMuted, size: 40),
          const SizedBox(height: VailTheme.md),
          Text('No sessions yet',
              style:
                  VailTheme.body.copyWith(color: VailTheme.textSecondary)),
          const SizedBox(height: VailTheme.sm),
          const Text('Start a conversation to see it here.',
              style: VailTheme.bodySmall),
        ],
      ),
    );
  }
}
