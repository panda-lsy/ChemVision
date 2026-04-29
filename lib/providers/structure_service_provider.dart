import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/mock_structure_service.dart';
import '../services/real_structure_service.dart';
import '../services/structure_service.dart';

final structureServiceProvider = Provider<StructureService>((ref) {
  if (AppConfig.useMockService) {
    return MockStructureService();
  }
  return RealStructureService();
});
