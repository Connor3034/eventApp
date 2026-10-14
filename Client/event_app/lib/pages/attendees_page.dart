import 'package:flutter/material.dart';

import '../events_service.dart';
import '../models/attendee.dart';
import '../models/event.dart';

class AttendeesPage extends StatefulWidget {
  const AttendeesPage({
    required this.eventsService,
    required this.event,
    super.key,
  });

  final EventsService eventsService;
  final Event event;

  @override
  State<AttendeesPage> createState() => _AttendeesPageState();
}

class _AttendeesPageState extends State<AttendeesPage> {
  List<Attendee> _attendees = const [];
  bool _isLoading = true;
  String? _error;

  bool get _isHost => widget.event.canDelete;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final attendees = await widget.eventsService.loadAttendees(widget.event.id);
      if (!mounted) return;
      setState(() {
        _attendees = attendees;
        _isLoading = false;
      });
    } on EventsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to connect to the server';
        _isLoading = false;
      });
    }
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite to event'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    controller.dispose();

    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) return;

    try {
      await widget.eventsService.invite(widget.event.id, trimmed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invited $trimmed')),
      );
      await _load();
    } on EventsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to connect to the server')),
      );
    }
  }

  Future<void> _remove(Attendee attendee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove attendee?'),
        content: Text('${attendee.displayName} will no longer be invited.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.eventsService.removeAttendee(widget.event.id, attendee.attendanceId);
      if (!mounted) return;
      await _load();
    } on EventsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to connect to the server')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendees'),
        actions: [
          IconButton(
            onPressed: _invite,
            tooltip: 'Invite someone',
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (_attendees.isEmpty) {
      return const Center(child: Text('No one has been invited yet'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attendees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final attendee = _attendees[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              attendee.displayName
                  .substring(0, 1)
                  .toUpperCase(),
            ),
          ),
          title: Text(attendee.displayName),
          subtitle: attendee.userName != null && attendee.email != null
              ? Text(attendee.email!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusChip(status: attendee.status),
              if (_isHost)
                IconButton(
                  onPressed: () => _remove(attendee),
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      'accepted' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      'declined' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
