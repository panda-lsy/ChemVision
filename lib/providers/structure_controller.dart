import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/structure_result.dart';
import '../services/structure_service.dart';
import 'structure_service_provider.dart';

enum StructureStatus { idle, loading, success, failure }

class StructureState {
  final StructureStatus status;
  final StructureResult? result;
  final String? errorMessage;

  const StructureState({
    required this.status,
    this.result,
    this.errorMessage,
  });

  StructureState copyWith({
    StructureStatus? status,
    StructureResult? result,
    bool clearResult = false,
    String? errorMessage,
  }) {
    return StructureState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: errorMessage,
    );
  }

  factory StructureState.initial() {
    return const StructureState(status: StructureStatus.idle);
  }
}

class StructureController extends StateNotifier<StructureState> {
  StructureController({required StructureService service})
      : _service = service,
        super(StructureState.initial());

  final StructureService _service;

  Future<void> generate(String query, {String? mode}) async {
    if (state.status == StructureStatus.loading) {
      return;
    }

    state = state.copyWith(
      status: StructureStatus.loading,
      errorMessage: null,
      clearResult: true,
    );
    await Future.delayed(AppConfig.mockDelay);

    final result = await _service.generateStructure(query, mode: mode);
    if (!result.isValid) {
      state = state.copyWith(
        status: StructureStatus.failure,
        errorMessage: result.message ?? '结构解析失败',
        clearResult: true,
      );
      return;
    }

    state = state.copyWith(status: StructureStatus.success, result: result);
  }

  void reset() {
    state = StructureState.initial();
  }
}

final structureControllerProvider =
    StateNotifierProvider<StructureController, StructureState>((ref) {
  final service = ref.watch(structureServiceProvider);
  return StructureController(service: service);
});
