import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reaction_equation.dart';
import '../models/reaction_favorite_item.dart';
import '../services/reaction_favorites_service.dart';

final reactionFavoritesServiceProvider =
    Provider<ReactionFavoritesService>((ref) {
  return ReactionFavoritesService();
});

class ReactionFavoritesState {
  const ReactionFavoritesState({
    this.items = const [],
    this.filteredItems = const [],
    this.searchQuery,
    this.selectedCategory,
    this.categories = const [],
    this.allTags = const [],
    this.isLoading = true,
  });

  final List<ReactionFavoriteItem> items;
  final List<ReactionFavoriteItem> filteredItems;
  final String? searchQuery;
  final String? selectedCategory;
  final List<String> categories;
  final List<String> allTags;
  final bool isLoading;

  ReactionFavoritesState copyWith({
    List<ReactionFavoriteItem>? items,
    List<ReactionFavoriteItem>? filteredItems,
    String? searchQuery,
    String? selectedCategory,
    List<String>? categories,
    List<String>? allTags,
    bool? isLoading,
    bool clearSearch = false,
    bool clearCategory = false,
  }) {
    return ReactionFavoritesState(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      categories: categories ?? this.categories,
      allTags: allTags ?? this.allTags,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ReactionFavoritesController
    extends StateNotifier<ReactionFavoritesState> {
  ReactionFavoritesController(this._service)
      : super(const ReactionFavoritesState()) {
    load();
  }

  final ReactionFavoritesService _service;

  void load() {
    final items = _service.getAll();
    final categories = _service.getAllCategories();
    final tags = _service.getAllTags();
    state = state.copyWith(
      items: items,
      filteredItems: items,
      categories: categories,
      allTags: tags,
      isLoading: false,
      clearSearch: true,
      clearCategory: true,
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
    final results = _service.search(q);
    state = state.copyWith(
      filteredItems: results,
      searchQuery: q,
    );
  }

  void filterByCategory(String? category) {
    if (category == null) {
      state = state.copyWith(
        filteredItems: state.items,
        clearCategory: true,
      );
      return;
    }
    final results =
        state.items.where((item) => item.category == category).toList();
    state = state.copyWith(
      filteredItems: results,
      selectedCategory: category,
    );
  }

  Future<void> add(ReactionEquation equation, {String? category}) async {
    final item = ReactionFavoriteItem.fromEquation(
      equation: equation,
      category: category,
    );
    await _service.add(item);
    load();
  }

  Future<void> updateItem(ReactionFavoriteItem item) async {
    await _service.update(item);
    load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    load();
  }
}

final reactionFavoritesControllerProvider = StateNotifierProvider<
    ReactionFavoritesController, ReactionFavoritesState>((ref) {
  final service = ref.watch(reactionFavoritesServiceProvider);
  return ReactionFavoritesController(service);
}, dependencies: [reactionFavoritesServiceProvider]);
