import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/photo.dart';

abstract class SearchRepository {
  Future<Either<Failure, List<Photo>>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    Map<String, dynamic>? filters,
  });

  Future<Either<Failure, List<String>>> getSearchSuggestions(String query);
  Future<Either<Failure, List<String>>> getSearchHistory();
  Future<Either<Failure, void>> addToSearchHistory(String query);
  Future<Either<Failure, void>> clearSearchHistory();
}