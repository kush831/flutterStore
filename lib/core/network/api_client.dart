import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';
import '../storage/app_prefs.dart';
import '../storage/session_store.dart';
import '../storage/storage_providers.dart';
import 'app_exception.dart';
import 'end_points.dart';
import 'json_reader.dart';
import 'session_events.dart';

class UploadFile {
  const UploadFile({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

/// One HTTP client for the whole app. Every method returns the response as a [JsonReader]
/// and throws [AppException] when anything goes wrong.
class ApiClient {
  ApiClient({required this.session, required this.prefs, required this.events}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
        // 4xx responses with a JSON body (validation errors) are read as normal API answers.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _addHeaders));
    if (kDebugMode) _dio.interceptors.add(_DebugLog());
  }

  final SessionStore session;
  final AppPrefs prefs;
  final SessionEvents events;
  late final Dio _dio;

  // ── Headers: exactly the Jetpack rules ─────────────────────────────────────
  //  • public-key endpoints  → publicKey + secretKey, never Authorization
  //  • logged in             → Authorization: <token>
  //  • logged out            → publicKey + secretKey
  //  • always                → locale
  void _addHeaders(RequestOptions o, RequestInterceptorHandler handler) {
    final h = o.headers;
    h['Accept'] = 'application/json';

    final isPublic = EndPoints.publicKeyEndpoints.any(o.path.contains);

    if (isPublic) {
      h.remove('Authorization');
      h['publicKey'] = session.publicKey;
      h['secretKey'] = session.secretKey;
    } else if (session.token.isNotEmpty) {
      final t = session.token;
      h['Authorization'] = t.startsWith('Bearer ') ? t : 'Bearer $t'; // "Bearer Bearer" kabhi nahi
    } else {
      h['publicKey'] = session.publicKey;
      h['secretKey'] = session.secretKey;
    }

    final locale = prefs.language;
    if (locale != null && locale.isNotEmpty) h['locale'] = locale;
    handler.next(o);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// GET. Retries twice on network problems (safe: GET does not change data).
  Future<JsonReader> get(
      String path, {
        Map<String, Object?>? query,
        Map<String, String>? headers,
        bool requireSuccess = true,
        int retries = 2,
        CancelToken? cancelToken,
      }) async {
    var attempt = 0;
    while (true) {
      try {
        return await _send(
          path,
          method: 'GET',
          query: _clean(query),
          options: Options(headers: headers),
          requireSuccess: requireSuccess,
          cancelToken: cancelToken,
        );
      } on AppException catch (e) {
        if (!e.isNetwork || attempt >= retries) rethrow;
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  /// POST application/x-www-form-urlencoded (most endpoints).
  Future<JsonReader> postForm(
      String path, [
        Map<String, Object?> fields = const {},
        Map<String, String>? headers,
        bool requireSuccess = true,
        CancelToken? cancelToken,
      ]) =>
      _send(
        path,
        method: 'POST',
        data: _clean(fields),
        options: Options(contentType: Headers.formUrlEncodedContentType, headers: headers),
        requireSuccess: requireSuccess,
        cancelToken: cancelToken,
      );

  /// POST application/json.
  Future<JsonReader> postJson(
      String path,
      Object body, {
        Map<String, String>? headers,
        bool requireSuccess = true,
        CancelToken? cancelToken,
      }) =>
      _send(
        path,
        method: 'POST',
        data: body,
        options: Options(contentType: Headers.jsonContentType, headers: headers),
        requireSuccess: requireSuccess,
        cancelToken: cancelToken,
      );

  /// POST multipart/form-data. The same key may appear several times (`product_image[0]`, `product_image[1]` …).
  Future<JsonReader> postMultipart(
      String path, {
        Map<String, Object?> fields = const {},
        List<(String, UploadFile)> files = const [],
        Map<String, String>? headers,
        bool requireSuccess = true,
        ProgressCallback? onProgress,
        CancelToken? cancelToken,
      }) {
    final form = FormData();
    for (final e in (_clean(fields) ?? const <String, dynamic>{}).entries) {
      form.fields.add(MapEntry(e.key, '${e.value}'));
    }
    for (final (key, f) in files) {
      form.files.add(MapEntry(key, MultipartFile.fromBytes(f.bytes, filename: f.filename)));
    }
    return _send(
      path,
      method: 'POST',
      data: form,
      options: Options(headers: headers, sendTimeout: const Duration(seconds: 90)),
      requireSuccess: requireSuccess,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// The raw bytes of an absolute URL. Sent WITHOUT the app's headers: the file may live on another host.
  Future<Uint8List> download(String url) async {
    try {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 30)),
      );
      return Uint8List.fromList(res.data ?? const <int>[]);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  /// Nulls dropped, values as text (an int or bool can be passed straight in).
  Map<String, dynamic>? _clean(Map<String, Object?>? m) {
    if (m == null) return null;
    return {
      for (final e in m.entries)
        if (e.value != null) e.key: e.value is String ? e.value : '${e.value}',
    };
  }

  Future<JsonReader> _send(
      String path, {
        required String method,
        Object? data,
        Map<String, dynamic>? query,
        Options? options,
        required bool requireSuccess,
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
      }) async {
    try {
      final res = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(method: method),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      return _unwrap(res, requireSuccess);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  JsonReader _unwrap(Response<Object?> res, bool requireSuccess) {
    final code = res.statusCode ?? 0;
    final body = res.data;
    if (body is! Map) {
      throw AppException(
        AppException.serverProblem,
        kind: ErrorKind.server,
        statusCode: code,
        detail: 'Not a JSON object (HTTP $code) for ${res.requestOptions.path}',
      );
    }
    final root = JsonReader(body);
    final result = root.str('result') ?? '';
    final message = root.text('message');

    if (result == '999') {
      events.sessionExpired(message);
      throw AppException(message, kind: ErrorKind.session, code: '999', statusCode: code);
    }
    if (requireSuccess && result != '1') {
      throw AppException(
        message.isEmpty ? AppException.generic : message,
        kind: ErrorKind.api,
        code: result,
        statusCode: code,
      );
    }
    return root;
  }

  AppException _map(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
        AppException(AppException.timedOut, kind: ErrorKind.timeout, detail: e.message),
    DioExceptionType.connectionError => AppException(
      AppException.noInternet,
      kind: ErrorKind.network,
      detail: kIsWeb
          ? 'No response. If the internet works, the server probably does not allow this website (CORS). ${e.message}'
          : e.message,
    ),
    DioExceptionType.cancel => const AppException('Cancelled', kind: ErrorKind.cancelled),
    _ => AppException(
      AppException.serverProblem,
      kind: ErrorKind.server,
      statusCode: e.response?.statusCode,
      detail: e.message,
    ),
  };
}

/// Debug builds only. Prints method, path and status: never headers, tokens or bodies.
/// Debug builds only. Prints the full URL, headers, request body and the response.
/// Secrets (Authorization, secretKey, password, access_token, OTP…) are masked.
/// Set _kLogSecrets = true to see them in full.
class _DebugLog extends Interceptor {
  static const _kLogSecrets = false;
  static const _kMaxBody = 6000; // characters of a response shown (the strings API is huge)
  static const _sensitive = {
    'authorization',
    'secretkey',
    'merchantsecretkey',
    'password',
    'access_pin',
    'access_token',
    'accesstoken',
    'otp',
  };
  static const _encoder = JsonEncoder.withIndent('  ');

  static void _print(String title, List<String> lines) {
    debugPrint('┌─ $title');
    for (final l in lines) {
      for (final part in l.split('\n')) {
        debugPrint('│ $part', wrapWidth: 1000);
      }
    }
    debugPrint('└──────────────────────────────────────');
  }

  static String _mask(String s) => s.length <= 6 ? '***' : '${s.substring(0, 4)}***(${s.length} chars)';

  static String _maskValue(String key, Object? v) =>
      (!_kLogSecrets && _sensitive.contains(key.toLowerCase())) ? _mask('$v') : '$v';

  static Object? _maskDeep(Object? v) {
    if (_kLogSecrets) return v;
    if (v is Map) {
      return {
        for (final e in v.entries)
          '${e.key}': _sensitive.contains('${e.key}'.toLowerCase()) ? _mask('${e.value}') : _maskDeep(e.value),
      };
    }
    if (v is List) return v.map(_maskDeep).toList();
    return v;
  }

  static String _pretty(Object? v) {
    try {
      return _encoder.convert(v);
    } catch (_) {
      return '$v';
    }
  }

  static String _truncate(String s) =>
      s.length <= _kMaxBody ? s : '${s.substring(0, _kMaxBody)}\n… (+${s.length - _kMaxBody} more characters)';

  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    o.extra['_t0'] = DateTime.now().millisecondsSinceEpoch;
    final lines = <String>[
      '${o.method} ${o.uri}',
      'Headers: ${_pretty({for (final e in o.headers.entries) e.key: _maskValue(e.key, e.value)})}',
    ];
    final d = o.data;
    if (d is FormData) {
      lines.add('Form fields:');
      lines.addAll(d.fields.map((f) => '  ${f.key} = ${_maskValue(f.key, f.value)}'));
      if (d.files.isNotEmpty) {
        lines.add('Files:');
        lines.addAll(d.files.map((f) => '  ${f.key} → ${f.value.filename} (${f.value.length} bytes)'));
      }
    } else if (d != null) {
      lines.add('Body: ${_pretty(_maskDeep(d))}');
    }
    _print('REQUEST', lines);
    h.next(o);
  }

  @override
  void onResponse(Response<dynamic> r, ResponseInterceptorHandler h) {
    final t0 = r.requestOptions.extra['_t0'] as int?;
    final ms = t0 == null ? '?' : '${DateTime.now().millisecondsSinceEpoch - t0}';
    _print('RESPONSE ${r.statusCode} · $ms ms', [
      '${r.requestOptions.method} ${r.requestOptions.uri}',
      _truncate(_pretty(_maskDeep(r.data))),
    ]);
    h.next(r);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler h) {
    final res = e.response;
    _print('ERROR ${e.type.name}${res == null ? '' : ' · HTTP ${res.statusCode}'}', [
      '${e.requestOptions.method} ${e.requestOptions.uri}',
      if (e.message != null) 'Message: ${e.message}',
      if (res?.data != null) _truncate(_pretty(_maskDeep(res!.data))),
    ]);
    h.next(e);
  }
}

final apiClientProvider = Provider<ApiClient>(
      (ref) => ApiClient(
    session: ref.watch(sessionStoreProvider),
    prefs: ref.watch(appPrefsProvider),
    events: ref.watch(sessionEventsProvider),
  ),
);