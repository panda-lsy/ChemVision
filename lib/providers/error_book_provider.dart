import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/error_book_item.dart';
import '../services/error_book_service.dart';

class ErrorBookState {
  const ErrorBookState({
    this.items = const [],
    this.filteredItems = const [],
    this.searchQuery,
    this.isLoading = true,
  });

  final List<ErrorBookItem> items;
  final List<ErrorBookItem> filteredItems;
  final String? searchQuery;
  final bool isLoading;

  ErrorBookState copyWith({
    List<ErrorBookItem>? items,
    List<ErrorBookItem>? filteredItems,
    String? searchQuery,
    bool? isLoading,
    bool clearSearch = false,
  }) {
    return ErrorBookState(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ErrorBookController extends StateNotifier<ErrorBookState> {
  ErrorBookController(this._service) : super(const ErrorBookState()) {
    load();
  }

  final ErrorBookService _service;

  void load() {
    final items = _service.getAll();
    state = state.copyWith(
      items: items,
      filteredItems: items,
      isLoading: false,
      clearSearch: true,
    );
  }

  void search(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      state = state.copyWith(
        filteredItems: state.items,
        clearSearch: true,
      );
      return;
    }
    final results = state.items.where((item) {
      return item.title.toLowerCase().contains(q.toLowerCase()) ||
          item.content.toLowerCase().contains(q.toLowerCase()) ||
          item.compoundName.toLowerCase().contains(q.toLowerCase());
    }).toList();
    state = state.copyWith(
      filteredItems: results,
      searchQuery: q,
    );
  }

  Future<void> add(ErrorBookItem item) async {
    await _service.add(item);
    load();
  }

  Future<void> toggleReviewed(String id) async {
    final item = _service.getById(id);
    if (item == null) return;
    await _service.update(item.copyWith(reviewed: !item.reviewed));
    load();
  }

  Future<void> updateNote(String id, String note) async {
    final item = _service.getById(id);
    if (item == null) return;
    await _service.update(item.copyWith(note: note));
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

final errorBookControllerProvider =
    StateNotifierProvider<ErrorBookController, ErrorBookState>((ref) {
  final service = ref.watch(errorBookServiceProvider);
  return ErrorBookController(service);
}, dependencies: [errorBookServiceProvider]);
