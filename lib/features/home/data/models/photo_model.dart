import '../../domain/entities/photo.dart';

class PhotoModel extends Photo {
  const PhotoModel({
    required super.id,
    required super.url,
    required super.thumbnailUrl,
    required super.author,
    required super.description,
    required super.likes,
    required super.width,
    required super.height,
    super.tags,
    super.downloadUrl,
    super.createdAt,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      url: json['urls']?['regular'] as String,
      thumbnailUrl: json['urls']?['thumb'] as String,
      author: json['user']?['name'] as String? ?? 'Unknown',
      description: json['description'] as String? ??
          json['alt_description'] as String? ??
          '',
      likes: json['likes'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((tag) => tag is String
          ? tag
          : tag['title'] as String?)
          .whereType<String>()
          .toList(),
      downloadUrl: json['links']?['download'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'urls': {
        'regular': url,
        'thumb': thumbnailUrl,
      },
      'user': {
        'name': author,
      },
      'description': description,
      'likes': likes,
      'width': width,
      'height': height,
      'tags': tags,
      'links': {
        'download': downloadUrl,
      },
      'created_at': createdAt?.toIso8601String(),
    };
  }

  PhotoModel copyWith({
    String? id,
    String? url,
    String? thumbnailUrl,
    String? author,
    String? description,
    int? likes,
    int? width,
    int? height,
    List<String>? tags,
    String? downloadUrl,
    DateTime? createdAt,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      author: author ?? this.author,
      description: description ?? this.description,
      likes: likes ?? this.likes,
      width: width ?? this.width,
      height: height ?? this.height,
      tags: tags ?? this.tags,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Photo toEntity() {
    return Photo(
      id: id,
      url: url,
      thumbnailUrl: thumbnailUrl,
      author: author,
      description: description,
      likes: likes,
      width: width,
      height: height,
      tags: tags,
      downloadUrl: downloadUrl,
      createdAt: createdAt,
    );
  }
}