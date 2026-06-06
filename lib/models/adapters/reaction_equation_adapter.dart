import 'package:hive/hive.dart';

import '../../models/reaction_equation.dart';

class ReactionMoleculeAdapter extends TypeAdapter<ReactionMolecule> {
  @override
  final int typeId = 12;

  @override
  ReactionMolecule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ReactionMolecule(
      smiles: fields[0] as String,
      name: fields[1] as String?,
      svgString: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReactionMolecule obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.smiles)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.svgString);
  }
}

class ArrowTypeAdapter extends TypeAdapter<ArrowType> {
  @override
  final int typeId = 13;

  @override
  ArrowType read(BinaryReader reader) {
    return ArrowType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ArrowType obj) {
    writer.writeByte(obj.index);
  }
}

class ReactionEquationAdapter extends TypeAdapter<ReactionEquation> {
  @override
  final int typeId = 11;

  @override
  ReactionEquation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ReactionEquation(
      title: fields[0] as String,
      reactants: (fields[1] as List).cast<ReactionMolecule>(),
      products: (fields[2] as List).cast<ReactionMolecule>(),
      conditions: (fields[3] as Map).cast<String, String>(),
      arrowType: fields[4] as ArrowType,
      rxnData: fields[5] as String?,
      svgString: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReactionEquation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.reactants)
      ..writeByte(2)
      ..write(obj.products)
      ..writeByte(3)
      ..write(obj.conditions)
      ..writeByte(4)
      ..write(obj.arrowType)
      ..writeByte(5)
      ..write(obj.rxnData)
      ..writeByte(6)
      ..write(obj.svgString);
  }
}
