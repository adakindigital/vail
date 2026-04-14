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

/// Desktop sessions (history) UI — full-width table-style list of past
/// conversations. No status-bar padding; the desktop shell owns the top bar.
///
/// Rendered by [SessionsView] via [ScreenTypeLayout.builder].
/// Do not use directly — always go through [SessionsView].
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
        SessionsState.error => _ErrorBody(
            message: context.read<SessionsViewModel>().errorMessage,
            onRetry: () => context.read<SessionsViewModel>().load(),
          ),
        SessionsState.loaded => _SessionsTable(
            onSwitchTab: widget.onSwitchTab,
          ),
      },
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _SessionsTable extends StatelessWidget {
  final void Function(int) onSwitchTab;

  const _SessionsTable({required this.onSwitchTab});

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

    return Column(
      children: [
        _TableHeader(
          onRefresh: () => context.read<SessionsViewModel>().load(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: VailTheme.sm),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: VailTheme.lg,
              endIndent: VailTheme.lg,
            ),
            itemBuilder: (context, index) => _SessionRow(
              session: sessions[index],
              onTap: () => _openSession(context, sessions[index].id),
              onDelete: () => context
                  .read<SessionsViewModel>()
                  .deleteSession(sessions[index].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final VoidCallback onRefresh;

  const _TableHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 5,
            child: Text('TITLE', style: VailTheme.sectionLabel),
          ),
          const Expanded(
            flex: 2,
            child: Text('UPDATED', style: VailTheme.sectionLabel),
          ),
          const Expanded(
            flex: 1,
            child: Text('MESSAGES', style: VailTheme.sectionLabel),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(
              Icons.refresh_rounded,
              color: VailTheme.textSecondary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionSummary session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionRow({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.md,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: VailTheme.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: VailTheme.sm),
                  Expanded(
                    child: Text(
                      session.displayTitle,
                      style: VailTheme.sessionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _relativeTime(session.updatedAt),
                style: VailTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${session.messageCount}',
                style: VailTheme.bodySmall,
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline_rounded,
                color: VailTheme.textMuted,
                size: 16,
              ),
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
              style: VailTheme.body.copyWith(color: VailTheme.textSecondary)),
          const SizedBox(height: VailTheme.sm),
          const Text('Start a conversation to see it here.',
              style: VailTheme.bodySmall),
        ],
      ),
    );
  }
}
