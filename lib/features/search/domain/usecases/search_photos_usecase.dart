import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../home/domain/entities/photo.dart';
import '../repositories/search_repository.dart';

class SearchPhotosUseCase implements UseCase<List<Photo>, SearchPhotosParams> {
  final SearchRepository _repository;

  SearchPhotosUseCase(this._repository);

  @override
  Future<Either<Failure, List<Photo>>> call(SearchPhotosParams params) async {
    return await _repository.searchPhotos(
      query: params.query,
      page: params.page,
      perPage: params.perPage,
      filters: params.filters,
    );
  }
}

class SearchPhotosParams {
  final String query;
  final int page;
  final int perPage;
  final Map<String, dynamic>? filters;

  const SearchPhotosParams({
    required this.query,
    required this.page,
    required this.perPage,
    this.filters,
  });

  SearchPhotosParams copyWith({
    String? query,
    int? page,
    int? perPage,
    Map<String, dynamic>? filters,
  }) {
    return SearchPhotosParams(
      query: query ?? this.query,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      filters: filters ?? this.filters,
    );
  }
}

// Additional use cases for search
class GetSearchSuggestionsUseCase implements UseCase<List<String>, String> {
  final SearchRepository _repository;

  GetSearchSuggestionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<String>>> call(String params) async {
    return await _repository.getSearchSuggestions(params);
  }
}

class GetSearchHistoryUseCase implements UseCase<List<String>, NoParams> {
  final SearchRepository _repository;

  GetSearchHistoryUseCase(this._repository);

  @override
  Future<Either<Failure, List<String>>> call(NoParams params) async {
    return await _repository.getSearchHistory();
  }
}

class ClearSearchHistoryUseCase implements UseCase<void, NoParams> {
  final SearchRepository _repository;

  ClearSearchHistoryUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await _repository.clearSearchHistory();
  }
}