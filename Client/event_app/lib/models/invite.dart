import 'event.dart';

class Invite {
  const Invite({
    required this.attendanceId,
    required this.eventId,
    required this.status,
    required this.name,
    required this.eventTime,
    required this.location,
    this.hostId,
    this.hostName,
  });

  final int attendanceId;
  final int eventId;
  final String status;
  final String name;
  final DateTime eventTime;
  final String location;
  final int? hostId;
  final String? hostName;

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      attendanceId: json['attendance_id'] as int,
      eventId: json['event_id'] as int,
      status: json['status'] as String? ?? 'pending',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Untitled event',
      eventTime: DateTime.parse(json['event_time'] as String).toLocal(),
      location: json['location'] as String? ?? '',
      hostId: json['user_id'] as int?,
      hostName: json['host_name'] as String?,
    );
  }

  /// Event-shaped view of the invite so it can reuse event widgets.
  Event get event => Event(
        id: eventId,
        name: name,
        location: location,
        eventTime: eventTime,
        userId: hostId,
        userName: hostName,
      );
}
