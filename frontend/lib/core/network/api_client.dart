import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio dio;
  String? _authToken;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        // Vision OCR plus declaration extraction can take longer on a cold
        // Railway instance. Do not cancel a real analysis after 25 seconds.
        receiveTimeout: const Duration(seconds: 180),
        sendTimeout: const Duration(seconds: 120),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Transform raw network / HTTP errors into user-friendly messages
          // so that UI code does not need to interpret low-level exceptions.
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.error is SocketException) {
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: e.error,
                message:
                    'Unable to connect to MAANAK server. Please check your internet connection and try again.',
              ),
            );
          }

          final statusCode = e.response?.statusCode;
          if (statusCode == 401) {
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: e.error,
                message: 'Session expired. Please log in again.',
              ),
            );
          }
          if (statusCode == 403) {
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: e.error,
                message:
                    'You do not have permission to perform this action.',
              ),
            );
          }
          if (statusCode == 404) {
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: e.error,
                message:
                    'The requested resource was not found on the server.',
              ),
            );
          }
          if (statusCode != null && statusCode >= 500) {
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: e.error,
                message:
                    'MAANAK server encountered an error. Please try again.',
              ),
            );
          }

          return handler.next(e);
        },
      ),
    );
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await dio.patch(path, data: data);
  }

  Future<Response> uploadFile(String path, FormData formData) async {
    return await dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
