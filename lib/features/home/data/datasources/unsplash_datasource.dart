import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_service.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../models/photo_model.dart';

abstract class UnsplashDataSource {
  Future<List<PhotoModel>> getPhotos({
    required int page,
    required int perPage,
    String? orderBy,
  });

  Future<List<PhotoModel>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    String? orderBy,
    String? color,
    String? orientation,
  });

  Future<PhotoModel> getPhotoById(String id);
}

class UnsplashDataSourceImpl implements UnsplashDataSource {
  final NetworkService _networkService;

  UnsplashDataSourceImpl({required NetworkService networkService})
      : _networkService = networkService;

  @override
  Future<List<PhotoModel>> getPhotos({
    required int page,
    required int perPage,
    String? orderBy,
  }) async {
    try {
      final response = await _networkService.get(
        ApiConstants.photosEndpoint,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (orderBy != null) 'order_by': orderBy,
          'client_id': ApiConstants.unsplashAccessKey,
        },
      );

      if (response.data is List) {
        return (response.data as List)
            .map((json) => PhotoModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Invalid response format');
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch photos: $e');
    }
  }

  @override
  Future<List<PhotoModel>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    String? orderBy,
    String? color,
    String? orientation,
  }) async {
    try {
      final sanitizedQuery = InputSanitizer.sanitizeText(query);

      final response = await _networkService.get(
        ApiConstants.searchEndpoint,
        queryParameters: {
          'query': sanitizedQuery,
          'page': page,
          'per_page': perPage,
          if (orderBy != null) 'order_by': orderBy,
          if (color != null) 'color': color,
          if (orientation != null) 'orientation': orientation,
          'client_id': ApiConstants.unsplashAccessKey,
        },
      );

      if (response.data['results'] is List) {
        return (response.data['results'] as List)
            .map((json) => PhotoModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Invalid response format');
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to search photos: $e');
    }
  }

  @override
  Future<PhotoModel> getPhotoById(String id) async {
    try {
      final sanitizedId = InputSanitizer.sanitizeText(id);

      final response = await _networkService.get(
        '${ApiConstants.photosEndpoint}/$sanitizedId',
        queryParameters: {
          'client_id': ApiConstants.unsplashAccessKey,
        },
      );

      return PhotoModel.fromJson(response.data as Map<String, dynamic>);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to fetch photo: $e');
    }
  }
}