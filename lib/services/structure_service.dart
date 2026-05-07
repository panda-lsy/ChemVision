import '../models/structure_result.dart';

abstract class StructureService {
  Future<StructureResult> generateStructure(String query, {String? mode});
}
