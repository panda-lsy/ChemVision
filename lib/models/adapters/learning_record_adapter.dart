import 'package:hive/hive.dart';

import '../../models/learning_record.dart';

/// LearningRecord Hive 适配器(typeId=22)
class LearningRecordAdapter extends TypeAdapter<LearningRecord> {
  @override
  final int typeId = 22;

  @override
  LearningRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return LearningRecord(
      id: fields[0] as String,
      scanHistoryId: (fields[1] as String?) ?? '',
      smiles: fields[2] as String,
      compoundName: fields[3] as String,
      action: LearningAction.values.firstWhere(
        (e) => e.name == fields[4],
        orElse: () => LearningAction.scan,
      ),
      knowledgePointIds:
          (fields[5] as List?)?.cast<String>() ?? const [],
      createdAt: fields[6] as DateTime,
      notes: fields[7] as String?,
      masteryDelta: (fields[8] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, LearningRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scanHistoryId)
      ..writeByte(2)
      ..write(obj.smiles)
      ..writeByte(3)
      ..write(obj.compoundName)
      ..writeByte(4)
      ..write(obj.action.name)
      ..writeByte(5)
      ..write(obj.knowledgePointIds)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.masteryDelta);
  }
}
