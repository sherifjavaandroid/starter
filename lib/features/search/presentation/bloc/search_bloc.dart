import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/search_photos_usecase.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchPhotosUseCase _searchPhotosUseCase;
  final GetSearchSuggestionsUseCase _getSearchSuggestionsUseCase;
  final GetSearchHistoryUseCase _getSearchHistoryUseCase;
  final ClearSearchHistoryUseCase _clearSearchHistoryUseCase;

  static const int _perPage = 20;
  int _currentPage = 1;
  bool _hasReachedMax = false;
  String _currentQuery = '';
  Map<String, dynamic> _currentFilters = {};

  SearchBloc({
    required SearchPhotosUseCase searchPhotosUseCase,
    required GetSearchSuggestionsUseCase getSearchSuggestionsUseCase,
    required GetSearchHistoryUseCase getSearchHistoryUseCase,
    required ClearSearchHistoryUseCase clearSearchHistoryUseCase,
  })  : _searchPhotosUseCase = searchPhotosUseCase,
        _getSearchSuggestionsUseCase = getSearchSuggestionsUseCase,
        _getSearchHistoryUseCase = getSearchHistoryUseCase,
        _clearSearchHistoryUseCase = clearSearchHistoryUseCase,
        super(SearchInitial()) {
    on<SearchPhotosEvent>(_onSearchPhotos);
    on<LoadMoreSearchResultsEvent>(_onLoadMoreResults);
    on<GetSearchSuggestionsEvent>(_onGetSearchSuggestions);
    on<LoadSearchHistoryEvent>(_onLoadSearchHistory);
    on<ClearSearchHistoryEvent>(_onClearSearchHistory);
    on<ApplyFiltersEvent>(_onApplyFilters);
  }

  Future<void> _onSearchPhotos(SearchPhotosEvent event, Emitter<SearchState> emit) async {
    if (event.query.trim().isEmpty) {
      emit(SearchInitial());
      return;
    }

    emit(SearchLoading());
    _currentPage = 1;
    _currentQuery = event.query;
    _hasReachedMax = false;

    final result = await _searchPhotosUseCase(
      SearchPhotosParams(
        query: _currentQuery,
        page: _currentPage,
        perPage: _perPage,
        filters: _currentFilters,
      ),
    );

    result.fold(
          (failure) => emit(SearchError(failure.message)),
          (photos) => emit(SearchSuccess(
        photos: photos,
        query: _currentQuery,
        hasReachedMax: false,
        filters: _currentFilters,
      )),
    );
  }

  Future<void> _onLoadMoreResults(LoadMoreSearchResultsEvent event, Emitter<SearchState> emit) async {
    if (state is SearchSuccess && !_hasReachedMax) {
      final currentState = state as SearchSuccess;
      _currentPage++;

      final result = await _searchPhotosUseCase(
        SearchPhotosParams(
          query: _currentQuery,
          page: _currentPage,
          perPage: _perPage,
          filters: _currentFilters,
        ),
      );

      result.fold(
            (failure) {
          _currentPage--; // Revert page increment on failure
          emit(currentState.copyWith(loadingMore: false));
        },
            (newPhotos) {
          if (newPhotos.isEmpty) {
            _hasReachedMax = true;
            emit(currentState.copyWith(hasReachedMax: true));
          } else {
            emit(SearchSuccess(
              photos: [...currentState.photos, ...newPhotos],
              query: _currentQuery,
              hasReachedMax: false,
              filters: _currentFilters,
            ));
          }
        },
      );
    }
  }

  Future<void> _onGetSearchSuggestions(GetSearchSuggestionsEvent event, Emitter<SearchState> emit) async {
    final result = await _getSearchSuggestionsUseCase(event.query);

    result.fold(
          (failure) => null, // Silently fail for suggestions
          (suggestions) {
        if (state is SearchInitial) {
          emit(SearchSuggestionsLoaded(suggestions));
        }
      },
    );
  }

  Future<void> _onLoadSearchHistory(LoadSearchHistoryEvent event, Emitter<SearchState> emit) async {
    final result = await _getSearchHistoryUseCase(NoParams());

    result.fold(
          (failure) => emit(SearchError(failure.message)),
          (history) => emit(SearchHistoryLoaded(history)),
    );
  }

  Future<void> _onClearSearchHistory(ClearSearchHistoryEvent event, Emitter<SearchState> emit) async {
    final result = await _clearSearchHistoryUseCase(NoParams());

    result.fold(
          (failure) => emit(SearchError(failure.message)),
          (_) => emit(SearchHistoryLoaded(const [])),
    );
  }

  Future<void> _onApplyFilters(ApplyFiltersEvent event, Emitter<SearchState> emit) async {
    _currentFilters = event.filters;

    if (_currentQuery.isNotEmpty) {
      // Re-search with new filters
      add(SearchPhotosEvent(query: _currentQuery));
    } else {
      // Just update the state with new filters
      if (state is SearchInitial) {
        emit(SearchInitial(filters: _currentFilters));
      }
    }
  }
}