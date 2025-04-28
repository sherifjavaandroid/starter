import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo.dart';

abstract class PhotoRepository {
  Future<Either<Failure, List<Photo>>> getPhotos({
    required int page,
    required int perPage,
    String? orderBy,
  });

  Future<Either<Failure, List<Photo>>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    String? orderBy,
    String? color,
    String? orientation,
  });

  Future<Either<Failure, Photo>> getPhotoById(String id);
}