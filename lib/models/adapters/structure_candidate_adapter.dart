import 'package:hive/hive.dart';

import '../structure_result.dart';

class StructureCandidateAdapter extends TypeAdapter<StructureCandidate> {
  @override
  final int typeId = 2;

  @override
  StructureCandidate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return StructureCandidate(
      smiles: fields[0] as String,
      resolvedName: fields[1] as String?,
      englishName: fields[2] as String?,
      chineseName: fields[3] as String?,
      molecularFormula: fields[4] as String,
      molecularWeight: fields[5] as double,
      source: fields[6] as String?,
      confidence: fields[7] as double,
      svgString: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StructureCandidate obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.smiles)
      ..writeByte(1)
      ..write(obj.resolvedName)
      ..writeByte(2)
      ..write(obj.englishName)
      ..writeByte(3)
      ..write(obj.chineseName)
      ..writeByte(4)
      ..write(obj.molecularFormula)
      ..writeByte(5)
      ..write(obj.molecularWeight)
      ..writeByte(6)
      ..write(obj.source)
      ..writeByte(7)
      ..write(obj.confidence)
      ..writeByte(8)
      ..write(obj.svgString);
  }
}
