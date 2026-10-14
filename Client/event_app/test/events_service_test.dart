import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:event_app/auth_service.dart';
import 'package:event_app/events_service.dart';

Map<String, dynamic> _eventJson({
  required int id,
  required String name,
  String location = 'Hall',
  String eventTime = '2026-01-01T10:00:00.000Z',
  bool canEdit = true,
  bool canDelete = true,
}) {
  return {
    'event_id': id,
    'name': name,
    'location': location,
    'event_time': eventTime,
    'user_id': 1,
    'user_name': 'tester',
    'can_edit': canEdit,
    'can_delete': canDelete,
  };
}

EventsService _serviceFor(MockClient client) {
  final authService = AuthService(client: client)..token = 'test-token';
  return EventsService(authService, client: client);
}

void main() {
  test('update sends a PUT and replaces the event in the list', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode([_eventJson(id: 1, name: 'Old')]), 200);
      }
      if (request.method == 'PUT') {
        return http.Response(jsonEncode(_eventJson(id: 1, name: 'New')), 200);
      }
      return http.Response('{}', 404);
    });
    final service = _serviceFor(client);

    await service.load();
    expect(service.events.single.name, 'Old');

    final updated = await service.update(
      id: 1,
      name: 'New',
      location: 'Park',
      eventTime: DateTime.utc(2026, 1, 1, 10),
    );

    expect(updated.name, 'New');
    expect(service.events.single.name, 'New');

    final put = requests.last;
    expect(put.method, 'PUT');
    expect(put.url.path, endsWith('/events/1'));
    expect(put.headers['Authorization'], 'Bearer test-token');
  });

  test('delete sends a DELETE and removes the event from the list', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode([_eventJson(id: 1, name: 'Old')]), 200);
      }
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      return http.Response('{}', 404);
    });
    final service = _serviceFor(client);

    await service.load();
    expect(service.events, hasLength(1));

    await service.delete(1);

    expect(service.events, isEmpty);
    final delete = requests.last;
    expect(delete.method, 'DELETE');
    expect(delete.url.path, endsWith('/events/1'));
  });

  test('update throws when the server rejects the request', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([_eventJson(id: 1, name: 'Old')]), 200);
      }
      return http.Response(jsonEncode({'error': 'Not allowed'}), 403);
    });
    final service = _serviceFor(client);

    await service.load();

    expect(
      () => service.update(
        id: 1,
        name: 'New',
        location: 'Park',
        eventTime: DateTime.utc(2026, 1, 1, 10),
      ),
      throwsA(isA<EventsException>()),
    );
  });

  test('loadInvites parses pending invites', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/invites')) {
        return http.Response(
          jsonEncode([
            {
              'attendance_id': 5,
              'event_id': 2,
              'status': 'pending',
              'name': 'Movie night',
              'event_time': '2026-03-04T18:30:00.000Z',
              'location': 'Cinema',
              'user_id': 9,
              'host_name': 'Alex',
            }
          ]),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final service = _serviceFor(client);

    await service.loadInvites();

    expect(service.pendingInvites, hasLength(1));
    expect(service.pendingInvites.single.name, 'Movie night');
    expect(service.pendingInvites.single.hostName, 'Alex');
  });

  test('invite posts an email and returns the created attendee', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'attendance_id': 7,
          'event_id': 2,
          'user_id': null,
          'status': 'pending',
          'user_name': null,
          'email': 'friend@example.com',
        }),
        201,
      );
    });
    final service = _serviceFor(client);

    final attendee = await service.invite(2, 'friend@example.com');

    expect(attendee.email, 'friend@example.com');
    expect(attendee.status, 'pending');
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, endsWith('/events/2/invite'));
    expect(jsonDecode(request.body)['email'], 'friend@example.com');
  });

  test('loadAttendees returns the attendee list', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode([
          {
            'attendance_id': 1,
            'event_id': 2,
            'user_id': 3,
            'status': 'accepted',
            'email': 'sam@example.com',
            'user_name': 'Sam',
          }
        ]),
        200,
      );
    });
    final service = _serviceFor(client);

    final attendees = await service.loadAttendees(2);

    expect(attendees, hasLength(1));
    expect(attendees.single.displayName, 'Sam');
  });

  test('removeAttendee sends a DELETE to the attendee endpoint', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });
    final service = _serviceFor(client);

    await service.removeAttendee(2, 7);

    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.path, endsWith('/events/2/attendees/7'));
  });

  test('respondToInvite patches the invite and clears it from the inbox',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/invites')) {
        return http.Response(
          jsonEncode([
            {
              'attendance_id': 5,
              'event_id': 2,
              'status': 'pending',
              'name': 'Movie night',
              'event_time': '2026-03-04T18:30:00.000Z',
              'location': 'Cinema',
              'user_id': 9,
              'host_name': 'Alex',
            }
          ]),
          200,
        );
      }
      if (request.method == 'PATCH') {
        return http.Response(
          jsonEncode({
            'attendance_id': 5,
            'event_id': 2,
            'user_id': 1,
            'status': 'accepted',
          }),
          200,
        );
      }
      if (request.method == 'GET') {
        return http.Response(jsonEncode([_eventJson(id: 2, name: 'Movie night')]), 200);
      }
      return http.Response('{}', 404);
    });
    final service = _serviceFor(client);

    await service.loadInvites();
    expect(service.pendingInvites, hasLength(1));

    await service.respondToInvite(5, accept: true);

    expect(service.pendingInvites, isEmpty);
    final patch = requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, endsWith('/invites/5'));
    expect(jsonDecode(patch.body)['status'], 'accepted');
  });
}
