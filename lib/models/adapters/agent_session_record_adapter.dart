import 'package:hive/hive.dart';

import '../../models/agent_session_record.dart';
import '../../models/agent_task.dart';

/// AgentSessionRecord Hive 适配器(typeId=23)
class AgentSessionRecordAdapter extends TypeAdapter<AgentSessionRecord> {
  @override
  final int typeId = 23;

  @override
  AgentSessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final sectionsRaw = (fields[8] as List?) ?? const [];
    final sections = sectionsRaw
        .whereType<AgentSessionSection>()
        .toList(growable: false);

    return AgentSessionRecord(
      id: fields[0] as String,
      type: AgentTaskType.values.firstWhere(
        (e) => e.name == fields[1],
        orElse: () => AgentTaskType.chat,
      ),
      status: AgentTaskStatus.values.firstWhere(
        (e) => e.name == fields[2],
        orElse: () => AgentTaskStatus.completed,
      ),
      userInput: fields[3] as String,
      createdAt: fields[4] as DateTime,
      resultTitle: fields[5] as String?,
      resultSummary: fields[6] as String?,
      sections: sections,
      safetyNotice: fields[9] as String?,
      error: fields[10] as String?,
      relatedKnowledgePointIds:
          (fields[11] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, AgentSessionRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.name)
      ..writeByte(2)
      ..write(obj.status.name)
      ..writeByte(3)
      ..write(obj.userInput)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.resultTitle)
      ..writeByte(6)
      ..write(obj.resultSummary)
      ..writeByte(8)
      ..write(obj.sections)
      ..writeByte(9)
      ..write(obj.safetyNotice)
      ..writeByte(10)
      ..write(obj.error)
      ..writeByte(11)
      ..write(obj.relatedKnowledgePointIds);
  }
}

/// AgentSessionSection Hive 适配器(typeId=24)
class AgentSessionSectionAdapter extends TypeAdapter<AgentSessionSection> {
  @override
  final int typeId = 24;

  @override
  AgentSessionSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AgentSessionSection(
      title: fields[0] as String,
      content: fields[1] as String,
      typeName: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AgentSessionSection obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.typeName);
  }
}
