import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/structure_result.dart';
import '../services/structure_service.dart';
import 'structure_service_provider.dart';

enum StructureStatus { idle, loading, success, failure }

enum LoadingStage {
  intentRecognition,
  structureInference,
  ruleValidation,
  renderOutput,
}

class StructureState {
  final StructureStatus status;
  final StructureResult? result;
  final String? errorMessage;
  final LoadingStage currentStage;
  final int candidateCount;

  const StructureState({
    required this.status,
    this.result,
    this.errorMessage,
    this.currentStage = LoadingStage.intentRecognition,
    this.candidateCount = 0,
  });

  StructureState copyWith({
    StructureStatus? status,
    StructureResult? result,
    bool clearResult = false,
    String? errorMessage,
    LoadingStage? currentStage,
    int? candidateCount,
  }) {
    return StructureState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: errorMessage,
      currentStage: currentStage ?? this.currentStage,
      candidateCount: candidateCount ?? this.candidateCount,
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
      currentStage: LoadingStage.intentRecognition,
      errorMessage: null,
      clearResult: true,
    );

    // Stage 0: Intent recognition (simulated timing)
    await Future.delayed(const Duration(milliseconds: 600));

    state = state.copyWith(currentStage: LoadingStage.structureInference);

    // Stage 1: Structure inference (actual service call)
    final result = await _service.generateStructure(query, mode: mode);
    if (!result.isValid) {
      state = state.copyWith(
        status: StructureStatus.failure,
        currentStage: LoadingStage.structureInference,
        errorMessage: result.message ?? '结构解析失败',
        clearResult: true,
      );
      return;
    }

    final count = 1 + result.alternatives.length;

    // Stage 2: Rule validation
    state = state.copyWith(
      currentStage: LoadingStage.ruleValidation,
      candidateCount: count,
    );
    await Future.delayed(const Duration(milliseconds: 500));

    // Stage 3: Render output
    state = state.copyWith(currentStage: LoadingStage.renderOutput);
    await Future.delayed(const Duration(milliseconds: 300));

    state = state.copyWith(
      status: StructureStatus.success,
      result: result,
    );
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
