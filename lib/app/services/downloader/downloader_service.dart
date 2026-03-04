import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloaderService {
  DownloaderService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
          headers: const {'User-Agent': _desktopUa},
        ),
      );

  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Safari/537.36';
  static const _mobileUa =
      'Mozilla/5.0 (Linux; Android 10; Infinix X688C) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36';

  final Dio _dio;

  Future<String> download({
    required String url,
    required String fileName,
    String? sourceUrl,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      await _saveFromUrl(url, fileName);
      onProgress?.call(1);
      return 'browser';
    }

    await _ensureStoragePermission();
    final savePath = await _createDownloadPath(fileName);
    final headerProfiles = _headerProfiles(Uri.parse(url), sourceUrl);
    DioException? lastDioError;
    int? lastStatusCode;

    for (final headers in headerProfiles) {
      try {
        final response = await _dio.download(
          url,
          savePath,
          options: Options(
            headers: headers,
            validateStatus: (code) => code != null && code < 500,
          ),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              onProgress?.call(received / total);
            }
          },
        );
        final status = response.statusCode;
        lastStatusCode = status;
        if (status != null && status >= 200 && status < 300) {
          onProgress?.call(1);
          return savePath;
        }
        if (status != 403) {
          break;
        }
      } on DioException catch (error) {
        lastDioError = error;
        lastStatusCode = error.response?.statusCode;
      }
    }

    if (lastStatusCode == 403) {
      throw Exception(
        'Download blocked by source server (HTTP 403). '
        'Try another quality/link, or use a public URL. '
        'Some platforms require auth/cookies and deny direct downloads.',
      );
    }
    if (lastStatusCode != null) {
      throw Exception('Download failed with HTTP $lastStatusCode.');
    }
    throw Exception(lastDioError?.message ?? 'Download failed.');
  }

  Future<String> _createDownloadPath(String fileName) async {
    final dir = await _resolveDownloadDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  Future<String> _saveFromUrl(String url, String fileName) async {
    throw UnsupportedError('saveFromUrl is intended for web only.');
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (!Platform.isAndroid) {
      return await getDownloadsDirectory() ??
          getApplicationDocumentsDirectory();
    }

    const paths = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/storage/self/primary/Download',
    ];
    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        return dir;
      }
    }
    return Directory(paths.first);
  }

  Future<void> _ensureStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    if ((await Permission.manageExternalStorage.request()).isGranted) {
      return;
    }
    final storage = await Permission.storage.request();
    if (storage.isGranted || storage.isLimited) {
      return;
    }
    throw Exception(
      'Storage permission denied. Please allow Files/Storage access '
      '(or All files access on Android 11+) and try again.',
    );
  }

  List<Map<String, dynamic>> _headerProfiles(
    Uri downloadUri,
    String? sourceUrl,
  ) {
    final sourceUri = Uri.tryParse(sourceUrl ?? '');
    final base = <String, dynamic>{
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
      'Range': 'bytes=0-',
    };
    final desktop = _withOrigin({...base, 'User-Agent': _desktopUa}, sourceUri);
    final mobile = _withOrigin({...base, 'User-Agent': _mobileUa}, sourceUri);
    return [
      desktop,
      mobile,
      {
        ...desktop,
        'Referer': '${downloadUri.scheme}://${downloadUri.host}/',
        'Origin': '${downloadUri.scheme}://${downloadUri.host}',
      },
      base,
    ];
  }

  Map<String, dynamic> _withOrigin(Map<String, dynamic> headers, Uri? source) {
    if (source == null || !source.hasScheme || source.host.isEmpty) {
      return headers;
    }
    return {
      ...headers,
      'Referer': source.toString(),
      'Origin': '${source.scheme}://${source.host}',
    };
  }
}
