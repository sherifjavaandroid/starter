import 'package:equatable/equatable.dart';

class Photo extends Equatable {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String author;
  final String description;
  final int likes;
  final int width;
  final int height;
  final List<String>? tags;
  final String? downloadUrl;
  final DateTime? createdAt;

  const Photo({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.author,
    required this.description,
    required this.likes,
    required this.width,
    required this.height,
    this.tags,
    this.downloadUrl,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    url,
    thumbnailUrl,
    author,
    description,
    likes,
    width,
    height,
    tags,
    downloadUrl,
    createdAt,
  ];

  double get aspectRatio => width / height;

  bool get isPortrait => height > width;

  bool get isLandscape => width > height;

  bool get hasDescription => description.isNotEmpty;

  bool get hasTags => tags != null && tags!.isNotEmpty;
}