import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadPhotosEvent extends HomeEvent {
  final String? orderBy;

  const LoadPhotosEvent({this.orderBy});

  @override
  List<Object?> get props => [orderBy];
}

class LoadMorePhotosEvent extends HomeEvent {
  const LoadMorePhotosEvent();
}

class RefreshPhotosEvent extends HomeEvent {
  const RefreshPhotosEvent();
}

class SearchPhotosEvent extends HomeEvent {
  final String query;
  final String? orderBy;
  final String? color;
  final String? orientation;

  const SearchPhotosEvent({
    required this.query,
    this.orderBy,
    this.color,
    this.orientation,
  });

  @override
  List<Object?> get props => [query, orderBy, color, orientation];
}