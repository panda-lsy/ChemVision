import 'package:hive/hive.dart';

import '../../models/error_book_item.dart';

class ErrorBookItemAdapter extends TypeAdapter<ErrorBookItem> {
  @override
  final int typeId = 25;

  @override
  ErrorBookItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ErrorBookItem(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      knowledgePointIds: (fields[4] as List?)?.cast<String>() ?? const [],
      smiles: (fields[5] as String?) ?? '',
      compoundName: (fields[6] as String?) ?? '',
      sourceSessionId: fields[7] as String?,
      note: (fields[8] as String?) ?? '',
      reviewed: (fields[9] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ErrorBookItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.knowledgePointIds)
      ..writeByte(5)
      ..write(obj.smiles)
      ..writeByte(6)
      ..write(obj.compoundName)
      ..writeByte(7)
      ..write(obj.sourceSessionId)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.reviewed);
  }
}
