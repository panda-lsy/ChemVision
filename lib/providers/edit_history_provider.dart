import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/edit_history_item.dart';
import '../services/edit_history_service.dart';

final editHistoryServiceProvider = Provider<EditHistoryService>((ref) {
  return EditHistoryService();
});

class EditHistoryState {
  const EditHistoryState({
    this.items = const [],
    this.isLoading = true,
  });

  final List<EditHistoryItem> items;
  final bool isLoading;

  EditHistoryState copyWith({
    List<EditHistoryItem>? items,
    bool? isLoading,
  }) {
    return EditHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class EditHistoryController extends StateNotifier<EditHistoryState> {
  EditHistoryController(this._service) : super(const EditHistoryState()) {
    load();
  }

  final EditHistoryService _service;

  void load() {
    final items = _service.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  Future<void> add(EditHistoryItem item) async {
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

final editHistoryControllerProvider =
    StateNotifierProvider<EditHistoryController, EditHistoryState>((ref) {
  final service = ref.watch(editHistoryServiceProvider);
  return EditHistoryController(service);
}, dependencies: [editHistoryServiceProvider]);
