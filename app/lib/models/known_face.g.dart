// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'known_face.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KnownFaceAdapter extends TypeAdapter<KnownFace> {
  @override
  final int typeId = 0;

  @override
  KnownFace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnownFace(
      faceId: fields[0] as String,
      name: fields[1] as String,
      imageBase64: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, KnownFace obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.faceId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imageBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnownFaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
