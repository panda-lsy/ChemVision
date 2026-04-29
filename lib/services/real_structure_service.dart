import '../models/structure_result.dart';
import 'structure_service.dart';

class RealStructureService implements StructureService {
  @override
  Future<StructureResult> generateStructure(String query) {
    throw UnimplementedError('RealStructureService is disabled in MVP.');
  }
}
