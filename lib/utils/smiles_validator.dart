/// Lightweight SMILES syntax validator and completeness scorer.
/// Does NOT replace RDKit — only catches obvious structural issues.
class SmilesValidator {
  SmilesValidator._();

  static const _validAtoms = {
    'H',
    'He',
    'Li',
    'Be',
    'B',
    'C',
    'N',
    'O',
    'F',
    'Ne',
    'Na',
    'Mg',
    'Al',
    'Si',
    'P',
    'S',
    'Cl',
    'Ar',
    'K',
    'Ca',
    'Sc',
    'Ti',
    'V',
    'Cr',
    'Mn',
    'Fe',
    'Co',
    'Ni',
    'Cu',
    'Zn',
    'Ga',
    'Ge',
    'As',
    'Se',
    'Br',
    'Kr',
    'Rb',
    'Sr',
    'Y',
    'Zr',
    'Nb',
    'Mo',
    'Tc',
    'Ru',
    'Rh',
    'Pd',
    'Ag',
    'Cd',
    'In',
    'Sn',
    'Sb',
    'Te',
    'I',
    'Xe',
    'Cs',
    'Ba',
    'La',
    'Ce',
    'Pr',
    'Nd',
    'Pm',
    'Sm',
    'Eu',
    'Gd',
    'Tb',
    'Dy',
    'Ho',
    'Er',
    'Tm',
    'Yb',
    'Lu',
    'Hf',
    'Ta',
    'W',
    'Re',
    'Os',
    'Ir',
    'Pt',
    'Au',
    'Hg',
    'Tl',
    'Pb',
    'Bi',
    'Po',
    'At',
    'Rn',
    'Fr',
    'Ra',
    'Ac',
    'Th',
    'Pa',
    'U',
    'Np',
    'Pu',
    'Am',
    'Cm',
    'Bk',
    'Cf',
    'Es',
    'Fm',
    'Md',
    'No',
    'Lr',
    'Rf',
    'Db',
    'Sg',
    'Bh',
    'Hs',
    'Mt',
    'Ds',
    'Rg',
    'Cn',
    'Nh',
    'Fl',
    'Mc',
    'Lv',
    'Ts',
    'Og',
  };

  static SmilesValidationReport validate(String smiles) {
    final raw = smiles.trim();
    if (raw.isEmpty) {
      return const SmilesValidationReport(
        isValid: false,
        completeness: 0,
        atomCount: 0,
        hasRingClosures: false,
        hasDisconnectedFragments: false,
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

    // 4. Token syntax (weight 0.20)
    final syntaxOk = _checkSyntax(raw);
    if (syntaxOk) {
      score += 0.20;
    } else {
      issues.add('invalid SMILES token');
    }

    // 5. Connectivity (weight 0.15)
    final disconnected = _hasDisconnectedFragments(raw);
    if (!disconnected) {
      score += 0.15;
    } else {
      issues.add('disconnected fragments (dot-separated)');
    }

    return SmilesValidationReport(
      isValid:
          syntaxOk && parenOk && ringOk && atomCount > 0 && atomCount <= 200,
      completeness: score.clamp(0.0, 1.0),
      atomCount: atomCount,
      hasRingClosures: _containsRingClosure(raw),
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
      if (c == '[') {
        final end = s.indexOf(']', i + 1);
        if (end < 0) return false;
        i = end;
        continue;
      }
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
    final openAtoms = <int, int>{};
    final openComponents = <int, int>{};
    final branchParents = <int?>[];
    var atomIndex = 0;
    var componentIndex = 0;
    int? currentAtom;

    void recordAtom() {
      currentAtom = atomIndex++;
    }

    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x5b) {
        final end = s.indexOf(']', i + 1);
        if (end < 0) return false;
        if (_parseBracketAtom(s.substring(i + 1, end)) == null) return false;
        recordAtom();
        i = end + 1;
        continue;
      }
      if (i + 1 < s.length) {
        final pair = s.substring(i, i + 2);
        if (pair == 'Cl' || pair == 'Br' || pair == 'se' || pair == 'as') {
          recordAtom();
          i += 2;
          continue;
        }
      }
      if ('BCNOPSFIbcnops*'.contains(String.fromCharCode(c))) {
        recordAtom();
        i++;
        continue;
      }
      if (c >= 0x30 && c <= 0x39) {
        final digit = c - 0x30;
        if (currentAtom == null) return false;
        if (openAtoms.containsKey(digit)) {
          if (openAtoms[digit] == currentAtom ||
              openComponents[digit] != componentIndex) {
            return false;
          }
          openAtoms.remove(digit);
          openComponents.remove(digit);
        } else {
          openAtoms[digit] = currentAtom!;
          openComponents[digit] = componentIndex;
        }
      } else if (c == 0x25) {
        if (i + 2 >= s.length) return false;
        final d1 = s.codeUnitAt(i + 1);
        final d2 = s.codeUnitAt(i + 2);
        if (d1 < 0x30 ||
            d1 > 0x39 ||
            d2 < 0x30 ||
            d2 > 0x39 ||
            currentAtom == null) {
          return false;
        }
        final digit = (d1 - 0x30) * 10 + (d2 - 0x30);
        if (openAtoms.containsKey(digit)) {
          if (openAtoms[digit] == currentAtom ||
              openComponents[digit] != componentIndex) {
            return false;
          }
          openAtoms.remove(digit);
          openComponents.remove(digit);
        } else {
          openAtoms[digit] = currentAtom!;
          openComponents[digit] = componentIndex;
        }
        i += 2;
      } else if (c == 0x28) {
        if (currentAtom == null) return false;
        branchParents.add(currentAtom);
      } else if (c == 0x29) {
        if (branchParents.isEmpty) return false;
        currentAtom = branchParents.removeLast();
      } else if (c == 0x2e) {
        currentAtom = null;
        componentIndex++;
      }
      i++;
    }
    return openAtoms.isEmpty && branchParents.isEmpty;
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
      if ('()-=#\$:/\\.%'.contains(c) || _isDigit(c.codeUnitAt(0))) {
        if (c == '%' && i + 2 < s.length) i += 2;
        i++;
        continue;
      }
      if (i + 1 < s.length &&
          (s.substring(i, i + 2) == 'Cl' || s.substring(i, i + 2) == 'Br')) {
        atoms.add(s.substring(i, i + 2));
        i += 2;
        continue;
      }
      if ('BCNOPSFI'.contains(c)) {
        atoms.add(c);
        i++;
        continue;
      }
      if (i + 1 < s.length &&
          (s.substring(i, i + 2) == 'se' || s.substring(i, i + 2) == 'as')) {
        atoms.add(s.substring(i, i + 2).toUpperCase());
        i += 2;
        continue;
      }
      if ('bcnops'.contains(c)) {
        atoms.add(c.toUpperCase());
      } else if (c == '*') {
        atoms.add(c);
      }
      i++;
    }
    return atoms;
  }

  static String? _parseBracketAtom(String bracket) {
    final match = RegExp(
      r'^\d*([A-Z][a-z]?|[bcnops]|se|as|\*)(?:@{1,2}|@(?:TH|AL|SP|TB|OH)\d?)?(?:H\d*)?(?:[+-]{1,2}|[+-]\d+)?(?::\d+)?$',
    ).firstMatch(bracket);
    if (match == null) return null;

    final symbol = match.group(1)!;
    if (symbol == '*') return symbol;
    if ('bcnops'.contains(symbol) || symbol == 'se' || symbol == 'as') {
      return symbol.toUpperCase();
    }
    return _validAtoms.contains(symbol) ? symbol : null;
  }

  static bool _checkSyntax(String s) {
    var atomCount = 0;
    var hasCurrentAtom = false;
    var hasPendingBond = false;
    final branchHasAtom = <bool>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == '[') {
        final end = s.indexOf(']', i + 1);
        if (end < 0 ||
            s.indexOf('[', i + 1) >= 0 && s.indexOf('[', i + 1) < end ||
            _parseBracketAtom(s.substring(i + 1, end)) == null) {
          return false;
        }
        atomCount++;
        hasCurrentAtom = true;
        hasPendingBond = false;
        for (var branch = 0; branch < branchHasAtom.length; branch++) {
          branchHasAtom[branch] = true;
        }
        i = end + 1;
        continue;
      }
      if (c == ']' || c.trim().isEmpty) return false;
      if (_isDigit(c.codeUnitAt(0))) {
        if (!hasCurrentAtom) return false;
        hasPendingBond = false;
        i++;
        continue;
      }
      if (c == '%') {
        if (i + 2 >= s.length ||
            !_isDigit(s.codeUnitAt(i + 1)) ||
            !_isDigit(s.codeUnitAt(i + 2)) ||
            !hasCurrentAtom) {
          return false;
        }
        hasPendingBond = false;
        i += 3;
        continue;
      }
      if (i + 1 < s.length &&
          (s.substring(i, i + 2) == 'Cl' || s.substring(i, i + 2) == 'Br')) {
        atomCount++;
        hasCurrentAtom = true;
        hasPendingBond = false;
        for (var branch = 0; branch < branchHasAtom.length; branch++) {
          branchHasAtom[branch] = true;
        }
        i += 2;
        continue;
      }
      if (i + 1 < s.length &&
          (s.substring(i, i + 2) == 'se' || s.substring(i, i + 2) == 'as')) {
        atomCount++;
        hasCurrentAtom = true;
        hasPendingBond = false;
        for (var branch = 0; branch < branchHasAtom.length; branch++) {
          branchHasAtom[branch] = true;
        }
        i += 2;
        continue;
      }
      if ('BCNOPSFI'.contains(c) || 'bcnops'.contains(c) || c == '*') {
        atomCount++;
        hasCurrentAtom = true;
        hasPendingBond = false;
        for (var branch = 0; branch < branchHasAtom.length; branch++) {
          branchHasAtom[branch] = true;
        }
        i++;
        continue;
      }
      if (c == '(') {
        if (!hasCurrentAtom || hasPendingBond) return false;
        branchHasAtom.add(false);
        i++;
        continue;
      }
      if (c == ')') {
        if (branchHasAtom.isEmpty ||
            !branchHasAtom.removeLast() ||
            hasPendingBond) {
          return false;
        }
        hasCurrentAtom = true;
        i++;
        continue;
      }
      if (c == '.') {
        if (!hasCurrentAtom || hasPendingBond || branchHasAtom.isNotEmpty) {
          return false;
        }
        hasCurrentAtom = false;
        i++;
        continue;
      }
      if ('-=#\$:/\\~'.contains(c)) {
        if (!hasCurrentAtom || hasPendingBond) return false;
        hasPendingBond = true;
        i++;
        continue;
      }
      return false;
    }
    return atomCount > 0 &&
        hasCurrentAtom &&
        !hasPendingBond &&
        branchHasAtom.isEmpty;
  }

  static bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  static bool _containsRingClosure(String s) {
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '[') {
        final end = s.indexOf(']', i + 1);
        if (end < 0) return false;
        i = end;
      } else if (_isDigit(s.codeUnitAt(i)) || s[i] == '%') {
        return true;
      }
    }
    return false;
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
