import 'package:equatable/equatable.dart';
import '../../../home/domain/entities/photo.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {
  final Map<String, dynamic> filters;

  const SearchInitial({this.filters = const {}});

  @override
  List<Object?> get props => [filters];
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchSuccess extends SearchState {
  final List<Photo> photos;
  final String query;
  final bool hasReachedMax;
  final bool loadingMore;
  final Map<String, dynamic> filters;

  const SearchSuccess({
    required this.photos,
    required this.query,
    this.hasReachedMax = false,
    this.loadingMore = false,
    this.filters = const {},
  });

  @override
  List<Object?> get props => [photos, query, hasReachedMax, loadingMore, filters];

  SearchSuccess copyWith({
    List<Photo>? photos,
    String? query,
    bool? hasReachedMax,
    bool? loadingMore,
    Map<String, dynamic>? filters,
  }) {
    return SearchSuccess(
      photos: photos ?? this.photos,
      query: query ?? this.query,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      loadingMore: loadingMore ?? this.loadingMore,
      filters: filters ?? this.filters,
    );
  }
}

class SearchSuggestionsLoaded extends SearchState {
  final List<String> suggestions;

  const SearchSuggestionsLoaded(this.suggestions);

  @override
  List<Object> get props => [suggestions];
}

class SearchHistoryLoaded extends SearchState {
  final List<String> history;

  const SearchHistoryLoaded(this.history);

  @override
  List<Object> get props => [history];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object> get props => [message];
}