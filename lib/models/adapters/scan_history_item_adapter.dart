import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../models/scan_history_item.dart';

class ScanHistoryItemAdapter extends TypeAdapter<ScanHistoryItem> {
  @override
  final int typeId = 21;

  @override
  ScanHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ScanHistoryItem(
      id: fields[0] as String,
      imageBytes: fields[1] as Uint8List,
      recognizedSmiles: fields[2] as String,
      completenessScore: (fields[3] as num).toDouble(),
      resolvedName: fields[4] as String?,
      englishName: fields[5] as String?,
      chineseName: fields[6] as String?,
      molecularFormula: (fields[7] as String?) ?? '',
      molecularWeight: (fields[8] as num?)?.toDouble() ?? 0,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistoryItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imageBytes)
      ..writeByte(2)
      ..write(obj.recognizedSmiles)
      ..writeByte(3)
      ..write(obj.completenessScore)
      ..writeByte(4)
      ..write(obj.resolvedName)
      ..writeByte(5)
      ..write(obj.englishName)
      ..writeByte(6)
      ..write(obj.chineseName)
      ..writeByte(7)
      ..write(obj.molecularFormula)
      ..writeByte(8)
      ..write(obj.molecularWeight)
      ..writeByte(9)
      ..write(obj.createdAt);
  }
}
