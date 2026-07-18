import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scan_history_item.dart';
import '../services/scan_history_service.dart';

final scanHistoryServiceProvider = Provider<ScanHistoryService>((ref) {
  return ScanHistoryService();
});

class ScanHistoryState {
  const ScanHistoryState({
    this.items = const [],
    this.isLoading = true,
  });

  final List<ScanHistoryItem> items;
  final bool isLoading;

  ScanHistoryState copyWith({
    List<ScanHistoryItem>? items,
    bool? isLoading,
  }) {
    return ScanHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ScanHistoryController extends StateNotifier<ScanHistoryState> {
  ScanHistoryController(this._service) : super(const ScanHistoryState()) {
    load();
  }

  final ScanHistoryService _service;

  void load() {
    final items = _service.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  Future<void> add(ScanHistoryItem item) async {
    await _service.add(item);
    load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    load();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    load();
  }
}

final scanHistoryControllerProvider =
    StateNotifierProvider<ScanHistoryController, ScanHistoryState>((ref) {
  final service = ref.watch(scanHistoryServiceProvider);
  return ScanHistoryController(service);
}, dependencies: [scanHistoryServiceProvider]);
