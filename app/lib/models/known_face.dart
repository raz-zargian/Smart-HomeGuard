import 'package:hive/hive.dart';

part 'known_face.g.dart';

@HiveType(typeId: 0)
class KnownFace extends HiveObject {
  @HiveField(0)
  String faceId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String imageBase64;

  @HiveField(3)
  String role;

  KnownFace({
    required this.faceId,
    required this.name,
    required this.imageBase64,
    required this.role,
  });
}
