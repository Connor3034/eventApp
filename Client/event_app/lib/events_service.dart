import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'models/event.dart';

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

  List<Event> get events => List.unmodifiable(_events);

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

  void clear() {
    _events = const [];
    error = null;
    isLoading = false;
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
