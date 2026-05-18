import 'package:hive/hive.dart';

part 'security_event.g.dart';

@HiveType(typeId: 1)
class SecurityEvent extends HiveObject {
  @HiveField(0)
  String eventId;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  String status;

  @HiveField(3)
  String? faceId;

  @HiveField(4)
  String imageUrl;

  SecurityEvent({
    required this.eventId,
    required this.timestamp,
    required this.status,
    this.faceId,
    required this.imageUrl,
  });
}
