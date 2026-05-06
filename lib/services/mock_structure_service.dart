import '../models/structure_result.dart';
import 'structure_service.dart';

class MockStructureService implements StructureService {
  final Map<String, StructureResult> _presets = {
    '苯甲酸': const StructureResult(
      smiles: 'c1ccc(cc1)C(=O)O',
      resolvedName: 'benzoic acid',
      molecularFormula: 'C7H6O2',
      molecularWeight: 122.12,
      isValid: true,
      confidence: 0.93,
    ),
    '乙醇': const StructureResult(
      smiles: 'CCO',
      resolvedName: 'ethanol',
      molecularFormula: 'C2H6O',
      molecularWeight: 46.07,
      isValid: true,
      confidence: 0.9,
    ),
    '2-甲基戊烷': const StructureResult(
      smiles: 'CC(C)CCC',
      resolvedName: '2-methylpentane',
      molecularFormula: 'C6H14',
      molecularWeight: 86.18,
      isValid: true,
      confidence: 0.88,
    ),
    '丙酮': const StructureResult(
      smiles: 'CC(=O)C',
      resolvedName: 'propan-2-one',
      molecularFormula: 'C3H6O',
      molecularWeight: 58.08,
      isValid: true,
      confidence: 0.9,
    ),
    '甲苯': const StructureResult(
      smiles: 'Cc1ccccc1',
      resolvedName: 'methylbenzene',
      molecularFormula: 'C7H8',
      molecularWeight: 92.14,
      isValid: true,
      confidence: 0.89,
    ),
  };

  @override
  Future<StructureResult> generateStructure(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return StructureResult.invalid(message: '请输入化学名称');
    }

    for (final entry in _presets.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return StructureResult.invalid(message: '请输入更准确的IUPAC命名');
  }
}
