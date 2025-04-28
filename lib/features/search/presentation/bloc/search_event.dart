import 'package:equatable/equatable.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchPhotosEvent extends SearchEvent {
  final String query;

  const SearchPhotosEvent({required this.query});

  @override
  List<Object> get props => [query];
}

class LoadMoreSearchResultsEvent extends SearchEvent {
  const LoadMoreSearchResultsEvent();
}

class GetSearchSuggestionsEvent extends SearchEvent {
  final String query;

  const GetSearchSuggestionsEvent({required this.query});

  @override
  List<Object> get props => [query];
}

class LoadSearchHistoryEvent extends SearchEvent {
  const LoadSearchHistoryEvent();
}

class ClearSearchHistoryEvent extends SearchEvent {
  const ClearSearchHistoryEvent();
}

class ApplyFiltersEvent extends SearchEvent {
  final Map<String, dynamic> filters;

  const ApplyFiltersEvent({required this.filters});

  @override
  List<Object> get props => [filters];
}