// Opt-in live tests: public chemistry inputs only, no AI key or student data.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chemvision/services/real_structure_service.dart';
import 'package:chemvision/services/structure_cache_store.dart';

const live = bool.fromEnvironment('LIVE_CHEMISTRY');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Flutter's test binding otherwise replaces every HTTP response with 400.
  // Opt-in only: restore real sockets for these public, non-sensitive inputs.
  if (live) HttpOverrides.global = null;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final observations = <Map<String, dynamic>>[];
  tearDownAll(() {
    if (live) {
      File(
        'docs/competitions/openatom-2026/evidence/live-public-chemistry.json',
      ).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'recordedAt': DateTime.now().toUtc().toIso8601String(), 'scope': 'Real NameToStructureService and public databases. English inputs; no LLM/OCSR call. In-memory SharedPreferences cache.', 'observations': observations})}\n',
      );
    }
  });
  for (final sample in {
    'ethanol': 'C2H6O',
    'benzoic acid': 'C7H6O2',
    'acetone': 'C3H6O',
  }.entries) {
    test(
      '真实英文解析与缓存 ${sample.key}',
      () async {
        final service = NameToStructureService();
        final cold = Stopwatch()..start();
        final result = await service.generateStructure(
          sample.key,
          mode: 'exact',
        );
        cold.stop();
        final cached = await StructureCacheStore().get(
          sample.key,
          mode: 'exact',
        );
        final warm = Stopwatch()..start();
        final repeated = await service.generateStructure(
          sample.key,
          mode: 'exact',
        );
        warm.stop();
        observations.add({
          'input': sample.key,
          'expectedFormula': sample.value,
          'actualFormula': result.molecularFormula,
          'smiles': result.smiles,
          'isValid': result.isValid,
          'coldElapsedMs': cold.elapsedMilliseconds,
          'warmElapsedMs': warm.elapsedMilliseconds,
          'cachePresent': cached != null,
          'message': result.message,
          'passed':
              result.isValid &&
              result.molecularFormula == sample.value &&
              cached != null,
        });
        expect(result.isValid, isTrue, reason: result.message);
        expect(result.molecularFormula, sample.value);
        expect(cached, isNotNull);
        expect(repeated.smiles, result.smiles);
      },
      skip: !live,
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
}
