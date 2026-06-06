import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite_item.dart';
import '../models/structure_result.dart';
import '../services/favorites_service.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

class FavoritesState {
  const FavoritesState({
    this.items = const [],
    this.filteredItems = const [],
    this.searchQuery,
    this.selectedCategory,
    this.selectedTag,
    this.categories = const [],
    this.allTags = const [],
    this.isLoading = true,
  });

  final List<FavoriteItem> items;
  final List<FavoriteItem> filteredItems;
  final String? searchQuery;
  final String? selectedCategory;
  final String? selectedTag;
  final List<String> categories;
  final List<String> allTags;
  final bool isLoading;

  FavoritesState copyWith({
    List<FavoriteItem>? items,
    List<FavoriteItem>? filteredItems,
    String? searchQuery,
    String? selectedCategory,
    String? selectedTag,
    List<String>? categories,
    List<String>? allTags,
    bool? isLoading,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearTag = false,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      filteredItems: filteredItems ?? this.filteredItems,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedTag: clearTag ? null : (selectedTag ?? this.selectedTag),
      categories: categories ?? this.categories,
      allTags: allTags ?? this.allTags,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController(this._service) : super(const FavoritesState()) {
    load();
  }

  final FavoritesService _service;

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
      clearTag: true,
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
    final results = _service.getByCategory(category);
    state = state.copyWith(
      filteredItems: results,
      selectedCategory: category,
    );
  }

  void filterByTag(String? tag) {
    if (tag == null) {
      state = state.copyWith(
        filteredItems: state.items,
        clearTag: true,
      );
      return;
    }
    final results = _service.getByTag(tag);
    state = state.copyWith(
      filteredItems: results,
      selectedTag: tag,
    );
  }

  Future<void> updateItem(FavoriteItem item) async {
    await _service.update(item);
    load();
  }

  Future<void> add(StructureResult result, String query,
      {String? category}) async {
    final item = FavoriteItem.fromResult(
      result: result,
      query: query,
      category: category,
    );
    await _service.add(item);
    load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    load();
  }

  String exportToSdf() {
    return _service.exportToSdf(state.filteredItems);
  }

  bool isFavorited(String smiles) {
    return state.items
        .any((item) => item.structureResult.smiles == smiles);
  }
}

final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, FavoritesState>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  return FavoritesController(service);
}, dependencies: [favoritesServiceProvider]);
