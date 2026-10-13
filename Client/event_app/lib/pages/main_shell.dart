import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../events_service.dart';
import 'calendar_page.dart';
import 'create_event.dart';
import 'home_page.dart';
import 'profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.authService,
    required this.eventsService,
    super.key,
  });

  final AuthService authService;
  final EventsService eventsService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.eventsService.load();
  }

  Future<void> _openCreateEvent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEvent(eventsService: widget.eventsService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            authService: widget.authService,
            eventsService: widget.eventsService,
            onSeeCalendar: () => setState(() => _index = 1),
          ),
          CalendarPage(eventsService: widget.eventsService),
          ProfilePage(authService: widget.authService),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              onPressed: _openCreateEvent,
              tooltip: 'Create event',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
