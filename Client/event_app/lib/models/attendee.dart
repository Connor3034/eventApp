class Attendee {
  const Attendee({
    required this.attendanceId,
    required this.eventId,
    required this.status,
    this.userId,
    this.userName,
    this.email,
  });

  final int attendanceId;
  final int eventId;
  final String status;
  final int? userId;
  final String? userName;
  final String? email;

  /// A display label: the account name when known, otherwise the email.
  String get displayName {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return 'Guest';
  }

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      attendanceId: json['attendance_id'] as int,
      eventId: json['event_id'] as int,
      status: json['status'] as String? ?? 'pending',
      userId: json['user_id'] as int?,
      userName: json['user_name'] as String?,
      email: json['email'] as String?,
    );
  }
}
