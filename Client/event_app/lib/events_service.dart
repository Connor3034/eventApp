import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'models/attendee.dart';
import 'models/event.dart';
import 'models/invite.dart';

class EventsException implements Exception {
  const EventsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EventsService extends ChangeNotifier {
  EventsService(
    this._authService, {
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  List<Event> _events = const [];
  bool isLoading = false;
  String? error;

  List<Invite> _pendingInvites = const [];
  bool isLoadingInvites = false;
  String? invitesError;

  List<Event> get events => List.unmodifiable(_events);

  List<Invite> get pendingInvites => List.unmodifiable(_pendingInvites);

  List<Event> get upcoming {
    final now = DateTime.now();
    return _events.where((event) => !event.eventTime.isBefore(now)).toList()
      ..sort((a, b) => a.eventTime.compareTo(b.eventTime));
  }

  List<Event> eventsOn(DateTime day) {
    return _events.where((event) => event.isOn(day)).toList()
      ..sort((a, b) => a.eventTime.compareTo(b.eventTime));
  }

  Future<void> load() async {
    final token = _authService.token;
    if (token == null) {
      _events = const [];
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/events'),
        headers: _headers(token),
      );
      if (response.statusCode != 200) {
        throw EventsException(_errorMessage(response, 'Unable to load events'));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const EventsException('Unexpected response from the server');
      }
      _events = decoded
          .map((item) => Event.fromJson(item as Map<String, dynamic>))
          .toList();
    } on EventsException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Unable to connect to the server';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Event> create({
    required String name,
    required String location,
    required DateTime eventTime,
  }) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events'),
      headers: _headers(token, withJson: true),
      body: jsonEncode({
        'name': name.trim(),
        'location': location.trim(),
        'event_time': eventTime.toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to create event'));
    }

    final created =
        Event.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _events = [..._events, created];
    notifyListeners();
    return created;
  }

  Future<Event> update({
    required int id,
    required String name,
    required String location,
    required DateTime eventTime,
  }) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.put(
      Uri.parse('$apiBaseUrl/events/$id'),
      headers: _headers(token, withJson: true),
      body: jsonEncode({
        'name': name.trim(),
        'location': location.trim(),
        'event_time': eventTime.toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to update event'));
    }

    final updated =
        Event.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _events = [
      for (final event in _events) if (event.id == id) updated else event,
    ];
    notifyListeners();
    return updated;
  }

  Future<void> delete(int id) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/events/$id'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to delete event'));
    }

    _events = _events.where((event) => event.id != id).toList();
    notifyListeners();
  }

  Future<void> loadInvites() async {
    final token = _authService.token;
    if (token == null) {
      _pendingInvites = const [];
      notifyListeners();
      return;
    }

    isLoadingInvites = true;
    invitesError = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/invites'),
        headers: _headers(token),
      );
      if (response.statusCode != 200) {
        throw EventsException(_errorMessage(response, 'Unable to load invites'));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const EventsException('Unexpected response from the server');
      }
      _pendingInvites = decoded
          .map((item) => Invite.fromJson(item as Map<String, dynamic>))
          .toList();
    } on EventsException catch (exception) {
      invitesError = exception.message;
    } catch (_) {
      invitesError = 'Unable to connect to the server';
    } finally {
      isLoadingInvites = false;
      notifyListeners();
    }
  }

  Future<void> respondToInvite(int attendanceId, {required bool accept}) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.patch(
      Uri.parse('$apiBaseUrl/invites/$attendanceId'),
      headers: _headers(token, withJson: true),
      body: jsonEncode({'status': accept ? 'accepted' : 'declined'}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to respond to invite'));
    }

    _pendingInvites =
        _pendingInvites.where((invite) => invite.attendanceId != attendanceId).toList();
    notifyListeners();

    // Accepting makes the event visible, so refresh the event list.
    if (accept) {
      await load();
    }
  }

  Future<List<Attendee>> loadAttendees(int eventId) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.get(
      Uri.parse('$apiBaseUrl/events/$eventId/attendees'),
      headers: _headers(token),
    );

    if (response.statusCode != 200) {
      throw EventsException(_errorMessage(response, 'Unable to load attendees'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const EventsException('Unexpected response from the server');
    }
    return decoded
        .map((item) => Attendee.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Attendee> invite(int eventId, String email) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.post(
      Uri.parse('$apiBaseUrl/events/$eventId/invite'),
      headers: _headers(token, withJson: true),
      body: jsonEncode({'email': email.trim()}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to send invite'));
    }

    return Attendee.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> removeAttendee(int eventId, int attendanceId) async {
    final token = _authService.token;
    if (token == null) {
      throw const EventsException('You need to be signed in');
    }

    final response = await _client.delete(
      Uri.parse('$apiBaseUrl/events/$eventId/attendees/$attendanceId'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EventsException(_errorMessage(response, 'Unable to remove attendee'));
    }
  }

  void clear() {
    _events = const [];
    _pendingInvites = const [];
    error = null;
    invitesError = null;
    isLoading = false;
    isLoadingInvites = false;
    notifyListeners();
  }

  Map<String, String> _headers(String token, {bool withJson = false}) => {
        'Authorization': 'Bearer $token',
        if (withJson) 'Content-Type': 'application/json',
      };

  String _errorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Fall through to the generic message.
    }
    return fallback;
  }
}
