class Event {
  const Event({
    required this.id,
    required this.name,
    required this.location,
    required this.eventTime,
    this.userId,
    this.userName,
  });

  final int id;
  final String name;
  final String location;
  final DateTime eventTime;
  final int? userId;
  final String? userName;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['event_id'] as int,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Untitled event',
      location: json['location'] as String? ?? '',
      eventTime: DateTime.parse(json['event_time'] as String).toLocal(),
      userId: json['user_id'] as int?,
      userName: json['user_name'] as String?,
    );
  }

  bool get isUpcoming => !eventTime.isBefore(DateTime.now());

  bool isOn(DateTime day) =>
      eventTime.year == day.year &&
      eventTime.month == day.month &&
      eventTime.day == day.day;
}
