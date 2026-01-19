import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the state of paginated data
class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot? lastDocument;

  const PaginatedState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    String? error,
    DocumentSnapshot? lastDocument,
    bool clearError = false,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  /// Initial loading state
  factory PaginatedState.initial() => const PaginatedState(isLoading: true);

  /// Empty state with no more items
  factory PaginatedState.empty() => const PaginatedState(hasMore: false);

  /// Error state
  factory PaginatedState.error(String message) => PaginatedState(
        isLoading: false,
        hasMore: false,
        error: message,
      );

  bool get isEmpty => items.isEmpty && !isLoading && !hasMore;
  bool get canLoadMore => !isLoading && hasMore;
  int get itemCount => items.length;
}

/// Configuration for pagination
class PaginationConfig {
  final int pageSize;
  final Duration debounceTime;

  const PaginationConfig({
    this.pageSize = 10,
    this.debounceTime = const Duration(milliseconds: 300),
  });

  static const PaginationConfig defaultConfig = PaginationConfig();
  static const PaginationConfig smallPageConfig = PaginationConfig(pageSize: 5);
  static const PaginationConfig largePageConfig = PaginationConfig(pageSize: 20);
}

/// Base class for paginated notifiers
abstract class PaginatedNotifier<T> extends StateNotifier<PaginatedState<T>> {
  final PaginationConfig config;

  PaginatedNotifier({this.config = PaginationConfig.defaultConfig})
      : super(PaginatedState.initial());

  /// Builds the base query for fetching data
  Query<Map<String, dynamic>> buildQuery(FirebaseFirestore firestore);

  /// Converts a Firestore document to the model type
  T fromDocument(DocumentSnapshot<Map<String, dynamic>> doc);

  /// Loads the initial page of data
  Future<void> loadInitial() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final query = buildQuery(FirebaseFirestore.instance).limit(config.pageSize);
      final snapshot = await query.get();

      final items = snapshot.docs.map((doc) => fromDocument(doc)).toList();
      final hasMore = items.length >= config.pageSize;

      state = PaginatedState(
        items: items,
        isLoading: false,
        hasMore: hasMore,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Loads the next page of data
  Future<void> loadMore() async {
    if (!state.canLoadMore || state.lastDocument == null) return;

    state = state.copyWith(isLoading: true);

    try {
      final query = buildQuery(FirebaseFirestore.instance)
          .startAfterDocument(state.lastDocument!)
          .limit(config.pageSize);

      final snapshot = await query.get();

      final newItems = snapshot.docs.map((doc) => fromDocument(doc)).toList();
      final hasMore = newItems.length >= config.pageSize;

      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoading: false,
        hasMore: hasMore,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.lastDocument,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refreshes the data from the beginning
  Future<void> refresh() async {
    state = PaginatedState.initial();
    await loadInitial();
  }

  /// Clears all data
  void clear() {
    state = const PaginatedState();
  }
}

/// A simpler pagination helper for one-off queries
class PaginationHelper {
  /// Fetches a paginated list from Firestore
  static Future<PaginatedResult<T>> fetchPaginated<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDocument,
    DocumentSnapshot? startAfter,
    int pageSize = 10,
  }) async {
    Query<Map<String, dynamic>> paginatedQuery = query.limit(pageSize);

    if (startAfter != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
    }

    final snapshot = await paginatedQuery.get();
    final items = snapshot.docs.map((doc) => fromDocument(doc)).toList();

    return PaginatedResult(
      items: items,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: items.length >= pageSize,
    );
  }

  /// Creates a paginated stream from Firestore
  static Stream<List<T>> paginatedStream<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDocument,
    int limit = 10,
  }) {
    return query.limit(limit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => fromDocument(doc)).toList(),
        );
  }
}

/// Result of a paginated fetch operation
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    this.lastDocument,
    this.hasMore = false,
  });

  bool get isEmpty => items.isEmpty;
  int get count => items.length;
}

/// Extension for easier pagination on Firestore queries
extension QueryPaginationExtension on Query<Map<String, dynamic>> {
  /// Fetches a single page of results
  Future<PaginatedResult<T>> fetchPage<T>({
    required T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDocument,
    DocumentSnapshot? startAfter,
    int pageSize = 10,
  }) {
    return PaginationHelper.fetchPaginated(
      query: this,
      fromDocument: fromDocument,
      startAfter: startAfter,
      pageSize: pageSize,
    );
  }

  /// Creates a limited stream of results
  Stream<List<T>> limitedStream<T>({
    required T Function(DocumentSnapshot<Map<String, dynamic>> doc) fromDocument,
    int limit = 10,
  }) {
    return PaginationHelper.paginatedStream(
      query: this,
      fromDocument: fromDocument,
      limit: limit,
    );
  }
}
