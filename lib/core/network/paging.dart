import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_exception.dart';

/// Kotlin's `size < loadSize` rule stopped every list after 10 items.
/// The correct rule: there is a next page only when the API sends a `nextPageUrl` AND this page had items.
int? nextPageOf(int page, String? nextPageUrl, {required bool gotItems}) {
  final has = nextPageUrl != null && nextPageUrl.trim().isNotEmpty && nextPageUrl != 'null';
  return (has && gotItems) ? page + 1 : null;
}

class PageResult<T> {
  const PageResult(this.items, this.nextPage);

  final List<T> items;
  final int? nextPage;
}

@immutable
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.nextPage,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.loadedOnce = false,
  });

  final List<T> items;
  final int? nextPage;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final String? loadMoreError;
  final bool loadedOnce;

  bool get hasMore => nextPage != null;

  /// First load, nothing to show yet → shimmer.
  bool get showShimmer => isRefreshing && items.isEmpty;

  /// Loaded fine, nothing came back → empty state.
  bool get showEmpty => loadedOnce && !isRefreshing && items.isEmpty && error == null;

  /// Failed and there is nothing to show → error state with retry. (With items on screen, a failed
  /// refresh keeps them and the screen can show a snackbar from [error].)
  bool get showError => error != null && items.isEmpty && !isRefreshing;

  PagedState<T> copyWith({
    List<T>? items,
    int? nextPage,
    bool clearNextPage = false,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    bool? loadedOnce,
  }) =>
      PagedState<T>(
        items: items ?? this.items,
        nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        loadMoreError: clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
        loadedOnce: loadedOnce ?? this.loadedOnce,
      );
}

/// Base class for every paged list. A subclass only says HOW to load one page:
///
///   class OrdersController extends PagedNotifier<Order> {
///     @override
///     Future<PageResult<Order>> fetchPage(int page) => ref.read(ordersRepositoryProvider).page(page, filter);
///   }
///
/// Filters live in the subclass; changing one calls [refresh].
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  int _generation = 0;

  Future<PageResult<T>> fetchPage(int page);

  /// false = the screen calls refresh() itself.
  bool get autoLoad => true;

  @override
  PagedState<T> build() {
    if (autoLoad) Future.microtask(refresh);
    return PagedState<T>(isRefreshing: autoLoad); // shimmer from the first frame
  }

  Future<void> refresh() async {
    final gen = ++_generation;
    state = state.copyWith(isRefreshing: true, isLoadingMore: false, clearError: true, clearLoadMoreError: true);
    try {
      final r = await fetchPage(1);
      if (gen != _generation) return; // a newer refresh (e.g. a filter change) won
      state = PagedState<T>(items: r.items, nextPage: r.nextPage, loadedOnce: true);
    } catch (e, st) {
      if (gen != _generation) return;
      if (e is! AppException) debugPrint('PagedNotifier refresh error: $e\n$st');
      if (e is AppException && e.isSession) return; // the router sends the user to login
      state = state.copyWith(isRefreshing: false, loadedOnce: true, error: AppException.messageOf(e));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (!s.hasMore || s.isLoadingMore || s.isRefreshing) return;
    final gen = _generation;
    state = s.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    try {
      final r = await fetchPage(s.nextPage!);
      if (gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...r.items],
        nextPage: r.nextPage,
        clearNextPage: r.nextPage == null,
        isLoadingMore: false,
      );
    } catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: AppException.messageOf(e));
    }
  }

  /// Change one item without reloading (optimistic switches, edited rows).
  void updateWhere(bool Function(T item) test, T Function(T item) update) {
    state = state.copyWith(items: [for (final i in state.items) test(i) ? update(i) : i]);
  }

  void removeWhere(bool Function(T item) test) {
    state = state.copyWith(items: state.items.where((i) => !test(i)).toList());
  }
}