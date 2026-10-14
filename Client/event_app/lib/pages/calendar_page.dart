import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../events_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import 'create_event.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({required this.eventsService, super.key});

  final EventsService eventsService;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar'), centerTitle: true),
      body: AnimatedBuilder(
        animation: widget.eventsService,
        builder: (context, _) {
          final selectedEvents = widget.eventsService.eventsOn(_selectedDay);

          return Column(
            children: [
              TableCalendar<Event>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: widget.eventsService.eventsOn,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  leftChevronIcon: const Icon(Icons.chevron_left),
                  rightChevronIcon: const Icon(Icons.chevron_right),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
              const Divider(height: 1),
              Expanded(child: _dayEvents(selectedEvents)),
            ],
          );
        },
      ),
    );
  }

  Widget _dayEvents(List<Event> events) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No events on this day',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final event = events[index];
        return EventCard(
          event: event,
          onTap: event.canEdit ? () => _openEvent(event) : null,
        );
      },
    );
  }

  void _openEvent(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEvent(
          eventsService: widget.eventsService,
          event: event,
        ),
      ),
    );
  }
}
