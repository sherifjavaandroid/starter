import 'package:equatable/equatable.dart';
import '../../domain/entities/photo.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final List<Photo> photos;
  final bool hasReachedMax;
  final bool loadingMore;
  final String? orderBy;

  const HomeLoaded(
      this.photos, {
        this.hasReachedMax = false,
        this.loadingMore = false,
        this.orderBy,
      });

  @override
  List<Object?> get props => [photos, hasReachedMax, loadingMore, orderBy];

  HomeLoaded copyWith({
    List<Photo>? photos,
    bool? hasReachedMax,
    bool? loadingMore,
    String? orderBy,
  }) {
    return HomeLoaded(
      photos ?? this.photos,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      loadingMore: loadingMore ?? this.loadingMore,
      orderBy: orderBy ?? this.orderBy,
    );
  }
}

class HomeSearchLoaded extends HomeState {
  final List<Photo> photos;
  final String query;
  final bool hasReachedMax;
  final String? orderBy;
  final String? color;
  final String? orientation;

  const HomeSearchLoaded({
    required this.photos,
    required this.query,
    this.hasReachedMax = false,
    this.orderBy,
    this.color,
    this.orientation,
  });

  @override
  List<Object?> get props => [photos, query, hasReachedMax, orderBy, color, orientation];

  HomeSearchLoaded copyWith({
    List<Photo>? photos,
    String? query,
    bool? hasReachedMax,
    String? orderBy,
    String? color,
    String? orientation,
  }) {
    return HomeSearchLoaded(
      photos: photos ?? this.photos,
      query: query ?? this.query,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      orderBy: orderBy ?? this.orderBy,
      color: color ?? this.color,
      orientation: orientation ?? this.orientation,
    );
  }
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object> get props => [message];
}