import 'package:hive/hive.dart';

import '../../models/edit_history_item.dart';

class EditHistoryItemAdapter extends TypeAdapter<EditHistoryItem> {
  @override
  final int typeId = 20;

  @override
  EditHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return EditHistoryItem(
      id: fields[0] as String,
      smiles: fields[1] as String,
      name: fields[2] as String?,
      isReaction: fields[3] as bool,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EditHistoryItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.smiles)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.isReaction)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
