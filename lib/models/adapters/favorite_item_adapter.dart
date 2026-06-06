import 'package:hive/hive.dart';

import '../favorite_item.dart';
import '../structure_result.dart';

class FavoriteItemAdapter extends TypeAdapter<FavoriteItem> {
  @override
  final int typeId = 0;

  @override
  FavoriteItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return FavoriteItem(
      id: fields[0] as String,
      structureResult: fields[1] as StructureResult,
      createdAt: fields[2] as DateTime,
      category: fields[3] as String?,
      query: fields[4] as String,
      tags: fields[5] != null
          ? (fields[5] as List).cast<String>()
          : const [],
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.structureResult)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.query)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.notes);
  }
}
