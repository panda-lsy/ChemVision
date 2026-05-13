import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/structure_recognition_result.dart';
import '../services/image_structure_service.dart';
import 'structure_service_provider.dart';

enum StructureRecognitionStatus {
  idle,
  analyzing,
  scoring,
  searching,
  complete,
  failure,
}

class StructureRecognitionState {
  const StructureRecognitionState({
    required this.status,
    this.result,
    this.errorMessage,
  });

  final StructureRecognitionStatus status;
  final StructureRecognitionResult? result;
  final String? errorMessage;

  StructureRecognitionState copyWith({
    StructureRecognitionStatus? status,
    StructureRecognitionResult? result,
    bool clearResult = false,
    String? errorMessage,
  }) {
    return StructureRecognitionState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: errorMessage,
    );
  }

  factory StructureRecognitionState.initial() {
    return const StructureRecognitionState(
      status: StructureRecognitionStatus.idle,
    );
  }
}

class StructureRecognitionController
    extends StateNotifier<StructureRecognitionState> {
  StructureRecognitionController({required ImageStructureService service})
      : _service = service,
        super(StructureRecognitionState.initial());

  final ImageStructureService _service;

  Future<void> recognizeFromImage(String dataUri) async {
    if (state.status == StructureRecognitionStatus.analyzing ||
        state.status == StructureRecognitionStatus.searching) {
      return;
    }

    state = StructureRecognitionState(
      status: StructureRecognitionStatus.analyzing,
      result: null,
      errorMessage: null,
    );

    try {
      final result = await _service.recognizeFromImage(dataUri);

      if (!result.isValid && result.recognizedSmiles.isEmpty) {
        state = StructureRecognitionState(
          status: StructureRecognitionStatus.failure,
          result: result,
          errorMessage: result.errorMessage ?? '识别失败',
        );
        return;
      }

      // Scoring stage
      state = StructureRecognitionState(
        status: StructureRecognitionStatus.scoring,
        result: result,
      );

      // If we have candidates, brief pause for UI transition
      if (result.candidates.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
        state = StructureRecognitionState(
          status: StructureRecognitionStatus.searching,
          result: result,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      state = StructureRecognitionState(
        status: StructureRecognitionStatus.complete,
        result: result,
      );
    } catch (e) {
      state = StructureRecognitionState(
        status: StructureRecognitionStatus.failure,
        errorMessage: '识别过程出错: $e',
      );
    }
  }

  void reset() {
    state = StructureRecognitionState.initial();
  }
}

final structureRecognitionControllerProvider = StateNotifierProvider<
    StructureRecognitionController, StructureRecognitionState>((ref) {
  final service = ref.watch(imageStructureServiceProvider);
  return StructureRecognitionController(service: service);
});
