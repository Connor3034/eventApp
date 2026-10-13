import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_app/auth_service.dart';
import 'package:event_app/events_service.dart';
import 'package:event_app/pages/home_page.dart';

void main() {
  testWidgets('home shows an empty state when there are no events',
      (WidgetTester tester) async {
    final authService = AuthService();
    final eventsService = EventsService(authService);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: authService,
          eventsService: eventsService,
        ),
      ),
    );

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('No upcoming events'), findsOneWidget);
  });
}
