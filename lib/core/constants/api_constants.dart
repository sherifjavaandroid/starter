class ApiConstants {
  // Base URLs
  static const String baseUrl = 'https://api.unsplash.com';
  static const String baseUrlDev = 'http://localhost:3000';
  static const String baseUrlStaging = 'https://staging-api.unsplash.com';

  // API Version
  static const String apiVersion = 'v1';

  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  static const String photos = '/photos';
  static const String photoDetails = '/photos/{id}';
  static const String searchPhotos = '/search/photos';
  static const String collections = '/collections';
  static const String collectionPhotos = '/collections/{id}/photos';

  static const String userProfile = '/users/{username}';
  static const String userPhotos = '/users/{username}/photos';
  static const String userLikes = '/users/{username}/likes';

  // Headers
  static const String acceptVersionHeader = 'Accept-Version';
  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';

  // Query Parameters
  static const String pageParam = 'page';
  static const String perPageParam = 'per_page';
  static const String queryParam = 'query';
  static const String orderByParam = 'order_by';
  static const String orientationParam = 'orientation';
  static const String colorParam = 'color';

  // Default Values
  static const int defaultPerPage = 20;
  static const int maxPerPage = 30;
  static const String defaultOrderBy = 'latest';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // API Keys (should be stored securely)
  static const String apiKey = 'YOUR_UNSPLASH_API_KEY';
  static const String secretKey = 'YOUR_UNSPLASH_SECRET_KEY';
}