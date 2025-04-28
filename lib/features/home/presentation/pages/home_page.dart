import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/photo_card.dart';
import '../widgets/secure_image_widget.dart';
import '../../../../core/security/security_manager.dart';
import '../../../../core/security/screenshot_prevention_service.dart';
import '../../../../core/utils/secure_logger.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  late final SecurityManager _securityManager;
  late final ScreenshotPreventionService _screenshotPrevention;
  late final SecureLogger _logger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _securityManager = context.read<SecurityManager>();
    _screenshotPrevention = context.read<ScreenshotPreventionService>();
    _logger = context.read<SecureLogger>();

    _initializePage();
    _setupScrollListener();
  }

  Future<void> _initializePage() async {
    // تفعيل حماية الصفحة
    await _screenshotPrevention.enableForPage();

    // تحديث نشاط المستخدم
    _securityManager.updateLastActivity();

    // تحميل البيانات
    context.read<HomeBloc>().add(LoadPhotosEvent());

    _logger.log(
      'Home page initialized',
      level: LogLevel.info,
      category: SecurityCategory.session,
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // تحديث نشاط المستخدم عند التمرير
      _securityManager.updateLastActivity();

      // تحميل المزيد عند الوصول لنهاية القائمة
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<HomeBloc>().add(LoadMorePhotosEvent());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // حماية البيانات عند دخول التطبيق للخلفية
      context.read<HomeBloc>().add(ClearSensitiveDataEvent());
    } else if (state == AppLifecycleState.resumed) {
      // إعادة تحميل البيانات عند العودة
      context.read<HomeBloc>().add(LoadPhotosEvent());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _screenshotPrevention.disableForPage();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _securityManager.updateLastActivity();
    context.read<HomeBloc>().add(RefreshPhotosEvent());
  }

  void _handleSearch() {
    _securityManager.updateLastActivity();
    Navigator.pushNamed(context, '/search');
  }

  void _handleLogout() {
    context.read<AuthBloc>().add(LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صور Unsplash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }

          if (state is HomeSecurityViolation) {
            // التعامل مع الانتهاكات الأمنية
            _logger.log(
              'Security violation detected: ${state.reason}',
              level: LogLevel.critical,
              category: SecurityCategory.security,
            );

            // تسجيل الخروج الفوري
            context.read<AuthBloc>().add(LogoutRequested());
          }
        },
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeLoaded) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: state.photos.length + (state.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.photos.length) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final photo = state.photos[index];
                  return PhotoCard(
                    photo: photo,
                    onTap: () => _handlePhotoTap(photo),
                  );
                },
              ),
            );
          }

          if (state is HomeError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleRefresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text('حالة غير معروفة'));
        },
      ),
    );
  }

  void _handlePhotoTap(Photo photo) {
    _securityManager.updateLastActivity();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecureImageWidget(
              imageUrl: photo.fullUrl,
              placeholder: photo.thumbUrl,
              protectedContent: true,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.author,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photo.description ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

// صفحة تفاصيل الصورة مع الحماية
class PhotoDetailPage extends StatefulWidget {
  final Photo photo;

  const PhotoDetailPage({
    Key? key,
    required this.photo,
  }) : super(key: key);

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  late final ScreenshotPreventionService _screenshotPrevention;

  @override
  void initState() {
    super.initState();
    _screenshotPrevention = context.read<ScreenshotPreventionService>();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _screenshotPrevention.enableForPage();
    await _screenshotPrevention.protectContent('photo_${widget.photo.id}');
  }

  @override
  void dispose() {
    _screenshotPrevention.unprotectContent('photo_${widget.photo.id}');
    _screenshotPrevention.disableForPage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الصورة'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SecureImageWidget(
              imageUrl: widget.photo.fullUrl,
              placeholder: widget.photo.thumbUrl,
              protectedContent: true,
              watermark: true,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.photo.author,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.photo.description ?? '',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildMetadata(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetadataItem('العرض', '${widget.photo.width} px'),
            _buildMetadataItem('الارتفاع', '${widget.photo.height} px'),
            _buildMetadataItem('الألوان', widget.photo.color),
            if (widget.photo.likes != null)
              _buildMetadataItem('الإعجابات', widget.photo.likes.toString()),
            if (widget.photo.downloads != null)
              _buildMetadataItem('التحميلات', widget.photo.downloads.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }
}