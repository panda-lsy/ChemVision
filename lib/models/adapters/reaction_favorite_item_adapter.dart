import 'package:hive/hive.dart';

import '../../models/reaction_equation.dart';
import '../../models/reaction_favorite_item.dart';

class ReactionFavoriteItemAdapter extends TypeAdapter<ReactionFavoriteItem> {
  @override
  final int typeId = 10;

  @override
  ReactionFavoriteItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ReactionFavoriteItem(
      id: fields[0] as String,
      equation: fields[1] as ReactionEquation,
      createdAt: fields[2] as DateTime,
      category: fields[3] as String?,
      tags: fields[4] != null ? (fields[4] as List).cast<String>() : const [],
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReactionFavoriteItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.equation)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.notes);
  }
}
