import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_photos_usecase.dart';
import '../../domain/usecases/search_photos_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetPhotosUseCase _getPhotosUseCase;
  final SearchPhotosUseCase _searchPhotosUseCase;

  static const int _perPage = 20;
  int _currentPage = 1;
  bool _hasReachedMax = false;

  HomeBloc({
    required GetPhotosUseCase getPhotosUseCase,
    required SearchPhotosUseCase searchPhotosUseCase,
  })  : _getPhotosUseCase = getPhotosUseCase,
        _searchPhotosUseCase = searchPhotosUseCase,
        super(HomeInitial()) {
    on<LoadPhotosEvent>(_onLoadPhotos);
    on<LoadMorePhotosEvent>(_onLoadMorePhotos);
    on<RefreshPhotosEvent>(_onRefreshPhotos);
    on<SearchPhotosEvent>(_onSearchPhotos);
  }

  Future<void> _onLoadPhotos(LoadPhotosEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    _currentPage = 1;
    _hasReachedMax = false;

    final result = await _getPhotosUseCase(
      GetPhotosParams(
        page: _currentPage,
        perPage: _perPage,
        orderBy: event.orderBy,
      ),
    );

    result.fold(
          (failure) => emit(HomeError(failure.message)),
          (photos) => emit(HomeLoaded(photos, hasReachedMax: false)),
    );
  }

  Future<void> _onLoadMorePhotos(LoadMorePhotosEvent event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded && !_hasReachedMax) {
      final currentState = state as HomeLoaded;
      _currentPage++;

      final result = await _getPhotosUseCase(
        GetPhotosParams(
          page: _currentPage,
          perPage: _perPage,
          orderBy: currentState.orderBy,
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
            emit(HomeLoaded(
              [...currentState.photos, ...newPhotos],
              hasReachedMax: false,
              orderBy: currentState.orderBy,
            ));
          }
        },
      );
    }
  }

  Future<void> _onRefreshPhotos(RefreshPhotosEvent event, Emitter<HomeState> emit) async {
    _currentPage = 1;
    _hasReachedMax = false;

    final currentState = state;
    String? orderBy;

    if (currentState is HomeLoaded) {
      orderBy = currentState.orderBy;
    }

    final result = await _getPhotosUseCase(
      GetPhotosParams(
        page: _currentPage,
        perPage: _perPage,
        orderBy: orderBy,
      ),
    );

    result.fold(
          (failure) => emit(HomeError(failure.message)),
          (photos) => emit(HomeLoaded(photos, hasReachedMax: false, orderBy: orderBy)),
    );
  }

  Future<void> _onSearchPhotos(SearchPhotosEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    _currentPage = 1;
    _hasReachedMax = false;

    final result = await _searchPhotosUseCase(
      SearchPhotosParams(
        query: event.query,
        page: _currentPage,
        perPage: _perPage,
        orderBy: event.orderBy,
        color: event.color,
        orientation: event.orientation,
      ),
    );

    result.fold(
          (failure) => emit(HomeError(failure.message)),
          (photos) => emit(HomeSearchLoaded(
        photos: photos,
        query: event.query,
        hasReachedMax: false,
        orderBy: event.orderBy,
        color: event.color,
        orientation: event.orientation,
      )),
    );
  }
}