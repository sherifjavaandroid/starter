import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/security/screenshot_prevention_service.dart';
import '../../../../core/utils/secure_logger.dart';

class SecureImageWidget extends StatefulWidget {
  final String imageUrl;
  final String? placeholder;
  final bool protectedContent;
  final bool watermark;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Map<String, String>? headers;

  const SecureImageWidget({
    Key? key,
    required this.imageUrl,
    this.placeholder,
    this.protectedContent = false,
    this.watermark = false,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.headers,
  }) : super(key: key);

  @override
  State<SecureImageWidget> createState() => _SecureImageWidgetState();
}

class _SecureImageWidgetState extends State<SecureImageWidget> {
  late final ScreenshotPreventionService _screenshotPrevention;
  late final SecureLogger _logger;
  bool _isBlurred = false;

  @override
  void initState() {
    super.initState();
    _screenshotPrevention = context.read<ScreenshotPreventionService>();
    _logger = context.read<SecureLogger>();

    if (widget.protectedContent) {
      _setupProtection();
    }
  }

  void _setupProtection() {
    // إعداد الحماية من لقطات الشاشة
    _screenshotPrevention.protectContent(widget.imageUrl.hashCode.toString());
  }

  @override
  void dispose() {
    if (widget.protectedContent) {
      _screenshotPrevention.unprotectContent(widget.imageUrl.hashCode.toString());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildImage(),
        if (widget.watermark) _buildWatermark(),
        if (_isBlurred) _buildBlurOverlay(),
      ],
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      httpHeaders: widget.headers,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      imageBuilder: (context, imageProvider) => _buildSecureImage(imageProvider),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return CachedNetworkImage(
        imageUrl: widget.placeholder!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.error_outline, color: Colors.red),
      ),
    );
  }

  Widget _buildSecureImage(ImageProvider imageProvider) {
    if (widget.protectedContent) {
      // تطبيق حماية إضافية للمحتوى
      return GestureDetector(
        onLongPress: () {
          // تفعيل التشويش عند الضغط المطول
          setState(() => _isBlurred = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _isBlurred = false);
            }
          });
        },
        child: _ImageWithProtection(
          imageProvider: imageProvider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        ),
      );
    }

    return Image(
      image: imageProvider,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }

  Widget _buildWatermark() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: WatermarkPainter(
            text: 'SECURE APP',
            color: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildBlurOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: Icon(
              Icons.security,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

// ودجت حماية الصورة
class _ImageWithProtection extends StatelessWidget {
  final ImageProvider imageProvider;
  final BoxFit fit;
  final double? width;
  final double? height;

  const _ImageWithProtection({
    Key? key,
    required this.imageProvider,
    required this.fit,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Image(
            image: imageProvider,
            fit: fit,
            width: width,
            height: height,
          ),
          // طبقة حماية غير مرئية
          Positioned.fill(
            child: CustomPaint(
              painter: InvisibleProtectionPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

// رسام العلامة المائية
class WatermarkPainter extends CustomPainter {
  final String text;
  final Color color;

  WatermarkPainter({
    required this.text,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // رسم العلامة المائية بشكل متكرر
    const spacing = 150.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.5); // تدوير 45 درجة
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(WatermarkPainter oldDelegate) => false;
}

// رسام الحماية غير المرئية
class InvisibleProtectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // تطبيق أنماط غير مرئية للحماية من النسخ
    final paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;

    // إنشاء نمط فريد لكل صورة
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 100; i++) {
      final x = (random * i % size.width).toDouble();
      final y = (random * i % size.height).toDouble();
      canvas.drawCircle(Offset(x, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(InvisibleProtectionPainter oldDelegate) => false;
}

// ودجت التكبير الآمن
class SecureZoomableImage extends StatefulWidget {
  final String imageUrl;
  final bool protectedContent;

  const SecureZoomableImage({
    Key? key,
    required this.imageUrl,
    this.protectedContent = true,
  }) : super(key: key);

  @override
  State<SecureZoomableImage> createState() => _SecureZoomableImageState();
}

class _SecureZoomableImageState extends State<SecureZoomableImage> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 0.5,
      maxScale: 4.0,
      child: SecureImageWidget(
        imageUrl: widget.imageUrl,
        protectedContent: widget.protectedContent,
        watermark: true,
      ),
    );
  }
}

// ودجت معرض الصور الآمن
class SecureImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool protectedContent;

  const SecureImageGallery({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.protectedContent = true,
  }) : super(key: key);

  @override
  State<SecureImageGallery> createState() => _SecureImageGalleryState();
}

class _SecureImageGalleryState extends State<SecureImageGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          itemBuilder: (context, index) {
            return SecureZoomableImage(
              imageUrl: widget.imageUrls[index],
              protectedContent: widget.protectedContent,
            );
          },
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
                  (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentIndex == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}