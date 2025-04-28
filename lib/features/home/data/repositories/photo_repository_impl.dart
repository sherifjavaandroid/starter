import 'package:dartz/dartz.dart';
import '../models/photo_model.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/photo.dart';
import '../../domain/repositories/photo_repository.dart';
import '../datasources/unsplash_datasource.dart';

class PhotoRepositoryImpl implements PhotoRepository {
  final UnsplashDataSource _dataSource;
  final NetworkInfo _networkInfo;

  PhotoRepositoryImpl({
    required UnsplashDataSource dataSource,
    required NetworkInfo networkInfo,
  })  : _dataSource = dataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, List<Photo>>> getPhotos({
    required int page,
    required int perPage,
    String? orderBy,
  }) async {
    if (!await _networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    try {
      final photoModels = await _dataSource.getPhotos(
        page: page,
        perPage: perPage,
        orderBy: orderBy,
      );

      final photos = photoModels.map((model) => model.toEntity()).toList();
      return Right(photos);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Photo>>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    String? orderBy,
    String? color,
    String? orientation,
  }) async {
    if (!await _networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    if (query.trim().isEmpty) {
      return Left(ValidationFailure('Search query cannot be empty'));
    }

    try {
      final photoModels = await _dataSource.searchPhotos(
        query: query,
        page: page,
        perPage: perPage,
        orderBy: orderBy,
        color: color,
        orientation: orientation,
      );

      final photos = photoModels.map((model) => model.toEntity()).toList();
      return Right(photos);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Photo>> getPhotoById(String id) async {
    if (!await _networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    if (id.trim().isEmpty) {
      return Left(ValidationFailure('Photo ID cannot be empty'));
    }

    try {
      final photoModel = await _dataSource.getPhotoById(id);
      return Right(photoModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}