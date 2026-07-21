import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:path_provider/path_provider.dart';

class DioClient {
  static DioClient? _instance;
  static DioClient get instance {
    if (_instance == null) {
      throw StateError('DioClient not initialized. Call DioClient.getInstance() first.');
    }
    return _instance!;
  }

  late Dio _dio;
  late DioCacheInterceptor _cacheInterceptor;
  late HiveCacheStore _cacheStore;

  DioClient._();

  static Future<DioClient> getInstance() async {
    if (_instance == null) {
      _instance = DioClient._();
      await _instance!._init();
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  Future<void> _init() async {
    final directory = await getApplicationDocumentsDirectory();
    _cacheStore = HiveCacheStore(
      '${directory.path}/dio_cache',
      hiveBoxName: 'dio_cache',
    );

    _cacheInterceptor = DioCacheInterceptor(
      options: CacheOptions(
        store: _cacheStore,
        policy: CachePolicy.refreshForceCache,
        maxStale: const Duration(days: 7),
        priority: CachePriority.normal,
      ),
    );

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
        },
        // Accept all status codes to handle 429 gracefully
        validateStatus: (status) => true,
      ),
    );

    _dio.interceptors.add(_cacheInterceptor);

    // Add retry interceptor for rate limiting (429) and server errors (5xx)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (_isRetryableError(error)) {
            final retryCount = _getRetryCount(error);
            if (retryCount < 3) {
              // Wait before retry (exponential backoff)
              await Future.delayed(Duration(seconds: retryCount + 1));
              
              try {
                final response = await _dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                // If retry fails, pass to next handler
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  bool _isRetryableError(DioException error) {
    final statusCode = error.response?.statusCode;
    // Retry on rate limiting (429) or server errors (5xx)
    return statusCode == 429 || (statusCode != null && statusCode >= 500);
  }

  int _getRetryCount(DioException error) {
    final extra = error.requestOptions.extra;
    return extra['retryCount'] ?? 0;
  }

  Dio get dio => _dio;
  HiveCacheStore get cacheStore => _cacheStore;

  /// Quick list cache: always refresh from network, serve stale while refreshing (stale-while-revalidate)
  /// For home screen — prioritize fresh data
  CacheOptions quickListCacheOptions() {
    return CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(hours: 1),
      hitCacheOnErrorExcept: [401, 403],
      priority: CachePriority.high,
    );
  }

  /// Enriched list cache: cache-first with 6h TTL
  CacheOptions enrichedListCacheOptions() {
    return CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.request,
      maxStale: const Duration(hours: 12),
      hitCacheOnErrorExcept: [401, 403],
      priority: CachePriority.high,
    );
  }

  /// Detail cache: cache-first with 6h TTL
  CacheOptions detailCacheOptions() {
    return CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.request,
      maxStale: const Duration(hours: 12),
      hitCacheOnErrorExcept: [401, 403],
      priority: CachePriority.normal,
    );
  }

  /// Search cache: 5 min TTL, stale-while-revalidate
  CacheOptions searchCacheOptions() {
    return CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(minutes: 30),
      hitCacheOnErrorExcept: [401, 403],
      priority: CachePriority.low,
    );
  }

  /// Category cache: 30 min TTL, stale-while-revalidate
  CacheOptions categoryCacheOptions() {
    return CacheOptions(
      store: _cacheStore,
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(hours: 1),
      hitCacheOnErrorExcept: [401, 403],
      priority: CachePriority.normal,
    );
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _cacheStore.clean();
  }

  /// Delete cache by key
  Future<void> deleteCacheKey(String key) async {
    await _cacheStore.delete(key);
  }
}
