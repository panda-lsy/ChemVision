import '../models/favorite_item.dart';
import '../models/structure_result.dart';

class SdfExportUtil {
  static String generateMolBlock(StructureResult result) {
    final name = result.resolvedName ?? result.englishName ?? 'Unknown';
    final now = DateTime.now();
    final dateStr =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.year}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final buf = StringBuffer();
    buf.writeln(name);
    buf.writeln('ChemEdu  $dateStr');
    buf.writeln('');
    buf.writeln('  0  0  0  0  0  0  0  0  0  0999 V2000');
    buf.writeln('> <SMILES>');
    buf.writeln(result.smiles);
    buf.writeln('');
    buf.writeln('> <MOLECULAR_FORMULA>');
    buf.writeln(result.molecularFormula);
    buf.writeln('');
    buf.writeln('> <MOLECULAR_WEIGHT>');
    buf.writeln(result.molecularWeight.toStringAsFixed(2));
    buf.writeln('');
    if (result.englishName != null && result.englishName!.isNotEmpty) {
      buf.writeln('> <IUPAC_NAME>');
      buf.writeln(result.englishName);
      buf.writeln('');
    }
    if (result.chineseName != null && result.chineseName!.isNotEmpty) {
      buf.writeln('> <CHINESE_NAME>');
      buf.writeln(result.chineseName);
      buf.writeln('');
    }
    if (result.confidence > 0) {
      buf.writeln('> <CONFIDENCE>');
      buf.writeln(result.confidence.toStringAsFixed(4));
      buf.writeln('');
    }
    buf.writeln('M  END');
    return buf.toString();
  }

  static String generateSdf(List<FavoriteItem> items) {
    return items.map((item) => generateMolBlock(item.structureResult)).join('\n\$\$\$\$\n');
  }
}
