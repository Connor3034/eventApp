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
}
