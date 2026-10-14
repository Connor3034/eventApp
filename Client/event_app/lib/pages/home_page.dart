import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../date_format.dart';
import '../events_service.dart';
import '../models/event.dart';
import '../models/invite.dart';
import '../widgets/event_card.dart';
import 'create_event.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.authService,
    required this.eventsService,
    this.onSeeCalendar,
    super.key,
  });

  final AuthService authService;
  final EventsService eventsService;
  final VoidCallback? onSeeCalendar;

  static const _maxUpcoming = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Home'), centerTitle: true),
      body: AnimatedBuilder(
        animation: eventsService,
        builder: (context, _) {
          final upcoming = eventsService.upcoming;
          final shown = upcoming.take(_maxUpcoming).toList();
          final invites = eventsService.pendingInvites;

          return RefreshIndicator(
            onRefresh: () async {
              await eventsService.load();
              await eventsService.loadInvites();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Hi ${_displayName()}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's what's coming up.",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (invites.isNotEmpty) ...[
                  Text(
                    'Invitations',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  for (final invite in invites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InviteCard(
                        invite: invite,
                        onAccept: () => _respond(context, invite, accept: true),
                        onDecline: () => _respond(context, invite, accept: false),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (onSeeCalendar != null && upcoming.isNotEmpty)
                      TextButton(
                        onPressed: onSeeCalendar,
                        child: const Text('View calendar'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._content(context, shown, upcoming.isNotEmpty),
              ],
            ),
          );
        },
      ),
    );
  }

  String _displayName() {
    final name = authService.user?.username.trim();
    if (name == null || name.isEmpty) {
      return 'there';
    }
    return name;
  }

  List<Widget> _content(
    BuildContext context,
    List<Event> shown,
    bool hasUpcoming,
  ) {
    if (eventsService.isLoading && eventsService.events.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (eventsService.error != null && eventsService.events.isEmpty) {
      return [
        _StatusMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load events",
          message: eventsService.error!,
          actionLabel: 'Try again',
          onAction: eventsService.load,
        ),
      ];
    }

    if (!hasUpcoming) {
      return const [_EmptyState()];
    }

    return [
      for (final event in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EventCard(
            event: event,
            onTap: event.canEdit ? () => _openEvent(context, event) : null,
          ),
        ),
    ];
  }

  void _openEvent(BuildContext context, Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEvent(
          eventsService: eventsService,
          event: event,
        ),
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    Invite invite, {
    required bool accept,
  }) async {
    try {
      await eventsService.respondToInvite(invite.attendanceId, accept: accept);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Invitation accepted' : 'Invitation declined'),
        ),
      );
    } on EventsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to connect to the server')),
      );
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  final Invite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invite.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${invite.hostName ?? 'Someone'} invited you',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatEventDate(invite.eventTime)} at ${formatEventTime(invite.eventTime)}'
              '${invite.location.isNotEmpty ? ' · ${invite.location}' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onDecline, child: const Text('Decline')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onAccept, child: const Text('Accept')),
              ],
            ),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No upcoming events',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to create your first event.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
