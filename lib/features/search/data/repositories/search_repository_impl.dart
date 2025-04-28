import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../home/data/datasources/unsplash_datasource.dart';
import '../../../home/domain/entities/photo.dart';
import '../../domain/repositories/search_repository.dart';
import 'dart:convert';

class SearchRepositoryImpl implements SearchRepository {
  final UnsplashDataSource _dataSource;
  final NetworkInfo _networkInfo;
  final SecureStorageService _secureStorage;

  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryItems = 10;

  SearchRepositoryImpl({
    required UnsplashDataSource dataSource,
    required NetworkInfo networkInfo,
    required SecureStorageService secureStorage,
  })  : _dataSource = dataSource,
        _networkInfo = networkInfo,
        _secureStorage = secureStorage;

  @override
  Future<Either<Failure, List<Photo>>> searchPhotos({
    required String query,
    required int page,
    required int perPage,
    Map<String, dynamic>? filters,
  }) async {
    if (!await _networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }

    if (query.trim().isEmpty) {
      return Left(ValidationFailure('Search query cannot be empty'));
    }

    try {
      final sanitizedQuery = InputSanitizer.sanitizeText(query);

      // Add to search history
      await addToSearchHistory(sanitizedQuery);

      final photoModels = await _dataSource.searchPhotos(
        query: sanitizedQuery,
        page: page,
        perPage: perPage,
        orderBy: filters?['orderBy'] as String?,
        color: filters?['color'] as String?,
        orientation: filters?['orientation'] as String?,
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
  Future<Either<Failure, List<String>>> getSearchSuggestions(String query) async {
    try {
      final history = await _getSearchHistoryList();

      if (query.isEmpty) {
        return Right(history);
      }

      final suggestions = history
          .where((item) => item.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return Right(suggestions);
    } catch (e) {
      return Left(CacheFailure('Failed to get search suggestions: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSearchHistory() async {
    try {
      final history = await _getSearchHistoryList();
      return Right(history);
    } catch (e) {
      return Left(CacheFailure('Failed to get search history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addToSearchHistory(String query) async {
    try {
      final sanitizedQuery = InputSanitizer.sanitizeText(query);
      if (sanitizedQuery.isEmpty) return const Right(null);

      var history = await _getSearchHistoryList();

      // Remove if already exists
      history.remove(sanitizedQuery);

      // Add to beginning
      history.insert(0, sanitizedQuery);

      // Keep only last N items
      if (history.length > _maxHistoryItems) {
        history = history.sublist(0, _maxHistoryItems);
      }

      final jsonString = json.encode(history);
      await _secureStorage.write(_searchHistoryKey, jsonString);

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to add to search history: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSearchHistory() async {
    try {
      await _secureStorage.delete(_searchHistoryKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to clear search history: $e'));
    }
  }

  Future<List<String>> _getSearchHistoryList() async {
    final historyJson = await _secureStorage.read(_searchHistoryKey);
    if (historyJson == null) return [];

    final List<dynamic> decoded = json.decode(historyJson);
    return decoded.cast<String>();
  }
}