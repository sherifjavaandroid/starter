import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../domain/entities/photo.dart';
import 'secure_image_widget.dart';

class PhotoCard extends StatelessWidget {
  final Photo photo;
  final VoidCallback? onTap;
  final bool showAuthor;
  final bool showLikes;

  const PhotoCard({
    Key? key,
    required this.photo,
    this.onTap,
    this.showAuthor = true,
    this.showLikes = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SecureImageWidget(
                imageUrl: photo.thumbnailUrl,
                placeholder: _buildPlaceholder(),
                errorWidget: _buildErrorWidget(),
                fit: BoxFit.cover,
              ),
            ),
            if (showAuthor || showLikes)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAuthor) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              photo.author,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (photo.hasDescription) ...[
                      Text(
                        photo.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (showLikes || photo.hasTags)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (showLikes)
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite_border,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${photo.likes}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          if (photo.hasTags)
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: _buildTags(context),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  List<Widget> _buildTags(BuildContext context) {
    if (photo.tags == null || photo.tags!.isEmpty) return [];

    final maxTags = 2;
    final tagsToShow = photo.tags!.take(maxTags).toList();
    final remainingTags = photo.tags!.length - maxTags;

    return [
      ...tagsToShow.map((tag) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Chip(
          label: Text(
            tag,
            style: const TextStyle(fontSize: 10),
          ),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      )),
      if (remainingTags > 0)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '+$remainingTags',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
    ];
  }
}

// Grid variant of PhotoCard
class PhotoGridCard extends StatelessWidget {
  final Photo photo;
  final VoidCallback? onTap;

  const PhotoGridCard({
    Key? key,
    required this.photo,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SecureImageWidget(
              imageUrl: photo.thumbnailUrl,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        photo.author,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photo.likes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}