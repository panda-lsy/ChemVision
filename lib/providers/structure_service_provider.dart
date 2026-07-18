import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/ai_settings_store.dart';
import '../services/decimer_client.dart';
import '../services/image_structure_service.dart';
import '../services/mock_structure_service.dart';
import '../services/real_structure_service.dart';
import '../services/structure_service.dart';
import '../services/vivo_aigc_client.dart';

final aiSettingsStoreProvider = Provider<AiSettingsStore>((ref) {
  return AiSettingsStore();
});

final vivoAigcClientProvider = Provider<VivoAigcClient>((ref) {
  return VivoAigcClient();
});

final decimerClientProvider = Provider<DecimerClient>((ref) {
  return DecimerClient();
});

final structureServiceProvider = Provider<StructureService>((ref) {
  if (AppConfig.useMockService) {
    return MockStructureService();
  }
  return NameToStructureService(
    settingsStore: ref.read(aiSettingsStoreProvider),
    client: ref.read(vivoAigcClientProvider),
  );
});

final imageStructureServiceProvider = Provider<ImageStructureService>((ref) {
  return ImageStructureService(
    decimerClient: ref.read(decimerClientProvider),
    settingsStore: ref.read(aiSettingsStoreProvider),
  );
});
