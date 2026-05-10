import 'package:hive/hive.dart';

import '../structure_result.dart';

class StructureResultAdapter extends TypeAdapter<StructureResult> {
  @override
  final int typeId = 1;

  @override
  StructureResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return StructureResult(
      smiles: fields[0] as String,
      resolvedName: fields[1] as String?,
      englishName: fields[2] as String?,
      chineseName: fields[3] as String?,
      svgString: fields[4] as String?,
      molecularFormula: fields[5] as String,
      molecularWeight: fields[6] as double,
      isValid: fields[7] as bool,
      confidence: fields[8] as double,
      message: fields[9] as String?,
      alternatives: (fields[10] as List?)?.cast<StructureCandidate>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, StructureResult obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.smiles)
      ..writeByte(1)
      ..write(obj.resolvedName)
      ..writeByte(2)
      ..write(obj.englishName)
      ..writeByte(3)
      ..write(obj.chineseName)
      ..writeByte(4)
      ..write(obj.svgString)
      ..writeByte(5)
      ..write(obj.molecularFormula)
      ..writeByte(6)
      ..write(obj.molecularWeight)
      ..writeByte(7)
      ..write(obj.isValid)
      ..writeByte(8)
      ..write(obj.confidence)
      ..writeByte(9)
      ..write(obj.message)
      ..writeByte(10)
      ..write(obj.alternatives);
  }
}
