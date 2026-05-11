import '../models/structure_result.dart';

abstract class StructureService {
  Future<StructureResult> generateStructure(String query, {String? mode});
  Future<StructureResult> reverseResolveName(String smiles);
  Future<StructureResult> resolveBySmiles(String smiles) => reverseResolveName(smiles);
}
