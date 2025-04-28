import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/photo.dart';
import '../repositories/photo_repository.dart';

class SearchPhotosUseCase implements UseCase<List<Photo>, SearchPhotosParams> {
  final PhotoRepository _repository;

  SearchPhotosUseCase(this._repository);

  @override
  Future<Either<Failure, List<Photo>>> call(SearchPhotosParams params) async {
    return await _repository.searchPhotos(
      query: params.query,
      page: params.page,
      perPage: params.perPage,
      orderBy: params.orderBy,
      color: params.color,
      orientation: params.orientation,
    );
  }
}

class SearchPhotosParams {
  final String query;
  final int page;
  final int perPage;
  final String? orderBy;
  final String? color;
  final String? orientation;

  const SearchPhotosParams({
    required this.query,
    required this.page,
    required this.perPage,
    this.orderBy,
    this.color,
    this.orientation,
  });

  SearchPhotosParams copyWith({
    String? query,
    int? page,
    int? perPage,
    String? orderBy,
    String? color,
    String? orientation,
  }) {
    return SearchPhotosParams(
      query: query ?? this.query,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      orderBy: orderBy ?? this.orderBy,
      color: color ?? this.color,
      orientation: orientation ?? this.orientation,
    );
  }
}