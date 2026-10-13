import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../events_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';

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

          return RefreshIndicator(
            onRefresh: eventsService.load,
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
          child: EventCard(event: event),
        ),
    ];
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
