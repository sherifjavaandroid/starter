import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/photo.dart';
import '../repositories/photo_repository.dart';

class GetPhotosUseCase implements UseCase<List<Photo>, GetPhotosParams> {
  final PhotoRepository _repository;

  GetPhotosUseCase(this._repository);

  @override
  Future<Either<Failure, List<Photo>>> call(GetPhotosParams params) async {
    return await _repository.getPhotos(
      page: params.page,
      perPage: params.perPage,
      orderBy: params.orderBy,
    );
  }
}

class GetPhotosParams {
  final int page;
  final int perPage;
  final String? orderBy;

  const GetPhotosParams({
    required this.page,
    required this.perPage,
    this.orderBy,
  });

  GetPhotosParams copyWith({
    int? page,
    int? perPage,
    String? orderBy,
  }) {
    return GetPhotosParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      orderBy: orderBy ?? this.orderBy,
    );
  }
}