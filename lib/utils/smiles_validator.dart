/// Lightweight SMILES syntax validator and completeness scorer.
/// Does NOT replace RDKit — only catches obvious structural issues.
class SmilesValidator {
  SmilesValidator._();

  static const _validAtoms = {
    'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
    'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
    'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Ga',
    'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Pd', 'Ag', 'Sn',
    'I', 'Xe', 'Ba', 'Pt', 'Au', 'Hg', 'Pb', 'Bi',
  };

  static SmilesValidationReport validate(String smiles) {
    final raw = smiles.trim();
    if (raw.isEmpty) {
      return const SmilesValidationReport(
        isValid: false, completeness: 0, atomCount: 0,
        hasRingClosures: false, hasDisconnectedFragments: false,
        issues: ['empty input'],
      );
    }

    final issues = <String>[];
    double score = 0;

    // 1. Parenthesis balance (weight 0.30)
    final parenOk = _checkParentheses(raw);
    if (parenOk) {
      score += 0.30;
    } else {
      issues.add('unmatched parentheses');
    }

    // 2. Atom count (weight 0.15)
    final atoms = _extractAtoms(raw);
    final atomCount = atoms.length;
    if (atomCount >= 2 && atomCount <= 200) {
      score += 0.15;
    } else if (atomCount == 1) {
      score += 0.08;
      issues.add('only one atom');
    } else {
      issues.add('atom count out of range: $atomCount');
    }

    // 3. Ring closure matching (weight 0.20)
    final ringOk = _checkRingClosures(raw);
    if (ringOk) {
      score += 0.20;
    } else {
      issues.add('unmatched ring closures');
    }

    // 4. Valence plausibility (weight 0.20)
    final valenceOk = _checkValence(raw, atoms);
    if (valenceOk) {
      score += 0.20;
    } else {
      issues.add('suspicious valence detected');
    }

    // 5. Connectivity (weight 0.15)
    final disconnected = _hasDisconnectedFragments(raw);
    if (!disconnected) {
      score += 0.15;
    } else {
      issues.add('disconnected fragments (dot-separated)');
    }

    return SmilesValidationReport(
      isValid: score >= 0.65,
      completeness: score.clamp(0.0, 1.0),
      atomCount: atomCount,
      hasRingClosures: raw.contains(RegExp(r'[0-9%]')),
      hasDisconnectedFragments: disconnected,
      issues: issues,
    );
  }

  static double analyzeCompleteness(String smiles) {
    return validate(smiles).completeness;
  }

  static bool _checkParentheses(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0;
  }

  static bool _checkRingClosures(String s) {
    final open = <int, int>{};
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) {
        // digit 0-9
        final digit = c - 0x30;
        if (open.containsKey(digit)) {
          open.remove(digit);
        } else {
          open[digit] = i;
        }
      } else if (c == 0x25 && i + 2 < s.length) {
        // %NN ring closure
        final d1 = s.codeUnitAt(i + 1);
        final d2 = s.codeUnitAt(i + 2);
        if (d1 >= 0x30 && d1 <= 0x39 && d2 >= 0x30 && d2 <= 0x39) {
          final digit = (d1 - 0x30) * 10 + (d2 - 0x30);
          if (open.containsKey(digit)) {
            open.remove(digit);
          } else {
            open[digit] = i;
          }
          i += 2;
        }
      }
      i++;
    }
    return open.isEmpty;
  }

  static bool _hasDisconnectedFragments(String s) {
    // Ignore dots inside bracket atoms like [Fe+2]
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '[') {
        depth++;
      } else if (c == ']') {
        depth--;
      } else if (c == '.' && depth == 0) {
        return true;
      }
    }
    return false;
  }

  static List<String> _extractAtoms(String s) {
    final atoms = <String>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == '[') {
        // bracket atom
        final end = s.indexOf(']', i);
        if (end > i) {
          final bracket = s.substring(i + 1, end);
          final atom = _parseBracketAtom(bracket);
          if (atom != null) atoms.add(atom);
          i = end + 1;
          continue;
        }
      }
      if (c == '(' || c == ')' || c == '.' || c == '-' || c == '=' ||
          c == '#' || c == ':' || c == '/' || c == '\\' || c == '+' ||
          c == '@' || c == '%' || (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39)) {
        i++;
        continue;
      }
      // Organic subset atoms
      if (i + 1 < s.length && _isLower(s[i + 1])) {
        final two = s.substring(i, i + 2);
        if (_validAtoms.contains(two)) {
          atoms.add(two);
          i += 2;
          continue;
        }
      }
      if (_validAtoms.contains(c)) {
        atoms.add(c);
      }
      i++;
    }
    return atoms;
  }

  static String? _parseBracketAtom(String bracket) {
    // Extract atom symbol from bracket like NH2, Fe, Cl
    final match = RegExp(r'^([A-Z][a-z]?)').firstMatch(bracket);
    if (match != null) {
      final symbol = match.group(1)!;
      if (_validAtoms.contains(symbol)) return symbol;
    }
    return null;
  }

  static bool _isLower(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x61 && code <= 0x7a;
  }

  static bool _checkValence(String s, List<String> atoms) {
    // Simplified: just check that we don't see obviously broken patterns
    // like CCCCCCCCC with no bonds (implausible connectivity)
    if (atoms.isEmpty) return true;
    // Check for consecutive organic atoms without any bond indicators
    // This is valid in SMILES (implicit single bonds), so we can't really
    // reject it. Instead, just verify no atom appears more than 50 times.
    final counts = <String, int>{};
    for (final a in atoms) {
      counts[a] = (counts[a] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      if (entry.value > 50) return false;
    }
    return true;
  }
}

class SmilesValidationReport {
  const SmilesValidationReport({
    required this.isValid,
    required this.completeness,
    required this.atomCount,
    required this.hasRingClosures,
    required this.hasDisconnectedFragments,
    required this.issues,
  });

  final bool isValid;
  final double completeness;
  final int atomCount;
  final bool hasRingClosures;
  final bool hasDisconnectedFragments;
  final List<String> issues;
}
