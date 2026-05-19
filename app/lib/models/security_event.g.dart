// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SecurityEventAdapter extends TypeAdapter<SecurityEvent> {
  @override
  final int typeId = 1;

  @override
  SecurityEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SecurityEvent(
      eventId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      status: fields[2] as String,
      faceId: fields[3] as String?,
      imageUrl: fields[4] as String,
      imageBase64: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SecurityEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.eventId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.faceId)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.imageBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
