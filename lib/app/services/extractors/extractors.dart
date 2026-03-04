import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:facebook_video_download/facebook_video_download.dart';
import 'package:insta_video_downloader/insta_video_downloader.dart';
import 'package:tiktok_scraper/enums.dart';
import 'package:tiktok_scraper/tiktok_scraper.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/video_models.dart';

class UrlClassifier {
  static const _directExt = ['.mp4', '.mkv', '.mov', '.webm', '.m3u8'];

  PlatformType classify(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be') || host.contains('youtube.com')) {
      return PlatformType.youtube;
    }
    if (host.contains('facebook.com') || host.contains('fb.watch')) {
      return PlatformType.facebook;
    }
    if (host.contains('twitter.com') || host.contains('x.com')) {
      return PlatformType.twitter;
    }
    if (host.contains('instagram.com')) {
      return PlatformType.instagram;
    }
    if (host.contains('tiktok.com')) {
      return PlatformType.tiktok;
    }
    final path = uri.path.toLowerCase();
    return _directExt.any(path.endsWith)
        ? PlatformType.direct
        : PlatformType.unknown;
  }
}

abstract class VideoExtractor {
  bool canHandle(Uri uri, PlatformType platform);
  Future<VideoInfo> extract(Uri uri);
}

class ExtractorRegistry {
  ExtractorRegistry(this._classifier);

  final UrlClassifier _classifier;
  final _extractors = <VideoExtractor>[
    YouTubeExtractor(),
    SocialPageExtractor(),
    DirectExtractor(),
  ];

  Future<VideoInfo> extract(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw Exception('Please enter a valid URL.');
    }

    final platform = _classifier.classify(uri);
    final candidates = _extractors
        .where((extractor) => extractor.canHandle(uri, platform))
        .toList();
    if (candidates.isEmpty) {
      throw Exception('This platform is not supported yet.');
    }

    Object? lastError;
    for (final extractor in candidates) {
      try {
        return await extractor.extract(uri);
      } catch (error) {
        lastError = error;
      }
    }
    final message = lastError?.toString() ?? 'Unable to extract media links.';
    throw Exception(message.replaceFirst('Exception: ', ''));
  }
}

class DirectExtractor implements VideoExtractor {
  static const _ext = ['mp4', 'mkv', 'mov', 'webm', 'm3u8'];

  @override
  bool canHandle(Uri uri, PlatformType platform) =>
      platform == PlatformType.direct;

  @override
  Future<VideoInfo> extract(Uri uri) async => VideoInfo(
    sourceUrl: uri.toString(),
    platform: PlatformType.direct,
    title: uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'direct_video',
    formats: [
      VideoFormat(
        id: 'direct_0',
        label: 'Auto',
        url: uri.toString(),
        container: _containerFromPath(uri.path),
        quality: 'Auto',
        hasAudio: true,
        isAdaptive: false,
      ),
    ],
  );

  String _containerFromPath(String path) {
    final lower = path.toLowerCase();
    for (final ext in _ext) {
      if (lower.endsWith('.$ext')) {
        return ext;
      }
    }
    return 'video';
  }
}

class SocialPageExtractor implements VideoExtractor {
  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Safari/537.36';
  static const _mobileUa =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Mobile Safari/537.36';

  SocialPageExtractor()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 40),
          followRedirects: true,
          headers: const {
            'User-Agent': _desktopUa,
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );

  final Dio _dio;
  static const _supported = {
    PlatformType.facebook,
    PlatformType.twitter,
    PlatformType.instagram,
    PlatformType.tiktok,
  };
  static const _mediaHostHints = {
    'fbcdn.net',
    'video.xx.fbcdn.net',
    'video.twimg.com',
    'twimg.com',
    'cdninstagram.com',
    'instagram.f',
    'tiktokcdn.com',
    'muscdn.com',
    'akamaized.net',
    'googlevideo.com',
  };
  static const _jsonMediaKeys = [
    'video_url',
    'playbackUrl',
    'playback_url',
    'contentUrl',
    'content_url',
    'videoUrl',
    'stream_url',
    'sd_src',
    'hd_src',
  ];

  @override
  bool canHandle(Uri uri, PlatformType platform) =>
      _supported.contains(platform);

  @override
  Future<VideoInfo> extract(Uri uri) async {
    final platform = _platformFromHost(uri.host);
    final html = await _fetchHtml(uri, platform);
    var mediaUrls = _findMediaUrls(html).toList();
    if (mediaUrls.isEmpty) {
      mediaUrls = await _fallbackMediaUrls(uri, platform);
    }
    if (mediaUrls.isEmpty) {
      throw Exception(
        'No downloadable media URL found. Try a public post URL. '
        'Private/login-protected posts can fail.',
      );
    }

    final title = _metaFirst(html, ['og:title', 'twitter:title']) ?? uri.host;
    final thumbnail = _metaFirst(html, [
      'og:image',
      'twitter:image',
      'twitter:image:src',
    ]);
    final formats = <VideoFormat>[];
    for (var i = 0; i < mediaUrls.length; i++) {
      final link = mediaUrls[i];
      final container = _containerFromUrl(link);
      final quality = _qualityFromUrl(link);
      formats.add(
        VideoFormat(
          id: 'social_$i',
          label: '$quality (${container.toUpperCase()})',
          url: link,
          container: container,
          quality: quality,
          hasAudio: true,
          isAdaptive: container == 'm3u8',
        ),
      );
    }
    formats.sort(
      (a, b) => _qualityRank(b.quality).compareTo(_qualityRank(a.quality)),
    );

    return VideoInfo(
      sourceUrl: uri.toString(),
      platform: platform,
      title: title.trim().isEmpty ? uri.host : title.trim(),
      thumbnailUrl: thumbnail,
      formats: formats,
    );
  }

  Future<String> _fetchHtml(Uri uri, PlatformType platform) async {
    int? lastStatus;
    Object? lastError;

    for (final attemptUri in _candidateUris(uri, platform)) {
      for (final headers in _headerProfiles(attemptUri)) {
        try {
          final res = await _dio.getUri<String>(
            attemptUri,
            options: Options(
              responseType: ResponseType.plain,
              headers: headers,
            ),
          );
          lastStatus = res.statusCode;
          final html = (res.data ?? '').toString();
          if (html.trim().isNotEmpty && (res.statusCode ?? 0) < 500) {
            return html;
          }
        } on DioException catch (error) {
          lastError = error;
          lastStatus = error.response?.statusCode;
        }
      }
    }

    if (lastStatus != null) {
      throw Exception(
        'Unable to read page (HTTP $lastStatus). Try a public post URL, not a private/share-only link.',
      );
    }
    throw Exception(lastError?.toString() ?? 'Unable to read page.');
  }

  List<Uri> _candidateUris(Uri uri, PlatformType platform) {
    final links = <String>{
      uri.toString(),
      uri.replace(fragment: '').toString(),
    };
    if (uri.queryParameters.isNotEmpty) {
      links.add(uri.replace(query: '', fragment: '').toString());
    }
    final host = uri.host.toLowerCase();
    if (host == 'x.com' && uri.path.startsWith('/i/web/status/')) {
      links.add(
        uri.replace(path: uri.path.replaceFirst('/i/web', '')).toString(),
      );
    }
    if (platform == PlatformType.facebook && host.contains('facebook.com')) {
      links.add(uri.replace(host: 'mbasic.facebook.com').toString());
      links.add(uri.replace(host: 'm.facebook.com').toString());
    }
    if (platform == PlatformType.instagram) {
      final clean = uri.replace(queryParameters: {}, fragment: '');
      links.add(clean.toString());
      links.add(
        clean.replace(queryParameters: {'__a': '1', '__d': 'dis'}).toString(),
      );
      links.add(clean.replace(path: '${clean.path}/embed').toString());
    }
    if (platform == PlatformType.tiktok) {
      links.add(uri.replace(path: '${uri.path}/embed').toString());
    }
    return links.map(Uri.parse).toList();
  }

  List<Map<String, String>> _headerProfiles(Uri uri) => [
    {
      'User-Agent': _desktopUa,
      'Referer': '${uri.scheme}://${uri.host}/',
      'Origin': '${uri.scheme}://${uri.host}',
    },
    {
      'User-Agent': _mobileUa,
      'Referer': '${uri.scheme}://${uri.host}/',
      'Origin': '${uri.scheme}://${uri.host}',
    },
    const {'User-Agent': _desktopUa},
  ];

  PlatformType _platformFromHost(String host) {
    final h = host.toLowerCase();
    if (h.contains('facebook.com') || h.contains('fb.watch')) {
      return PlatformType.facebook;
    }
    if (h.contains('twitter.com') || h.contains('x.com')) {
      return PlatformType.twitter;
    }
    if (h.contains('instagram.com')) {
      return PlatformType.instagram;
    }
    if (h.contains('tiktok.com')) {
      return PlatformType.tiktok;
    }
    return PlatformType.unknown;
  }

  Iterable<String> _findMediaUrls(String html) sync* {
    final found = <String>{};
    final metaKeys = [
      'og:video',
      'og:video:url',
      'og:video:secure_url',
      'twitter:player:stream',
    ];
    for (final key in metaKeys) {
      for (final value in _metaAll(html, key)) {
        final normalized = _normalizeUrl(_decodeMaybeJsonString(value));
        if (_isMediaUrl(normalized) && found.add(normalized)) {
          yield normalized;
        }
      }
    }

    for (final key in _jsonMediaKeys) {
      final escaped = RegExp.escape(key);
      final pattern = RegExp(
        '"$escaped"\\s*:\\s*"([^"]+)"',
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(html)) {
        final normalized = _normalizeUrl(
          _decodeMaybeJsonString(match.group(1) ?? ''),
        );
        if (_isMediaUrl(normalized) && found.add(normalized)) {
          yield normalized;
        }
      }
    }

    final m3u8Matches = RegExp(
      r'https?:\\?/\\?/[^<>\s]+\.m3u8[^<>\s]*',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in m3u8Matches) {
      final candidate = _normalizeUrl(
        _decodeMaybeJsonString(match.group(0) ?? ''),
      );
      if (_isMediaUrl(candidate) && found.add(candidate)) {
        yield candidate;
      }
    }

    final rawUrlMatches = RegExp(
      r'https?:\\?/\\?/[^<>\s]+',
      caseSensitive: false,
    ).allMatches(html);
    for (final match in rawUrlMatches) {
      final candidate = _normalizeUrl(
        _decodeMaybeJsonString(match.group(0) ?? ''),
      );
      if (_isMediaUrl(candidate) && found.add(candidate)) {
        yield candidate;
      }
    }
  }

  String? _metaFirst(String html, List<String> keys) {
    for (final key in keys) {
      final values = _metaAll(html, key);
      if (values.isNotEmpty) {
        return values.first;
      }
    }
    return null;
  }

  List<String> _metaAll(String html, String key) {
    final escaped = RegExp.escape(key);
    final byPropThenContent = RegExp(
      '<meta[^>]*(?:property|name)=[\'"]$escaped[\'"][^>]*content=[\'"]([^\'"]+)[\'"][^>]*>',
      caseSensitive: false,
    );
    final byContentThenProp = RegExp(
      '<meta[^>]*content=[\'"]([^\'"]+)[\'"][^>]*(?:property|name)=[\'"]$escaped[\'"][^>]*>',
      caseSensitive: false,
    );
    final values = <String>[];
    for (final r in [byPropThenContent, byContentThenProp]) {
      for (final m in r.allMatches(html)) {
        final value = m.group(1);
        if (value != null && value.trim().isNotEmpty) {
          values.add(value.trim());
        }
      }
    }
    return values;
  }

  String _normalizeUrl(String value) {
    var out = value.trim();
    out = out.replaceAll(r'\/', '/');
    out = out.replaceAll(r'\u002F', '/');
    out = out.replaceAll(r'\\u002F', '/');
    out = out.replaceAll(r'\\/', '/');
    out = out.replaceAll('\\/', '/');
    out = out.replaceAll('&amp;', '&');
    out = out.replaceAll('\\u0026', '&');
    out = out.replaceAll('\\x26', '&');
    out = out.replaceAll(RegExp("^[\"']+|[\"',\\\\]+\$"), '');
    return out;
  }

  String _decodeMaybeJsonString(String value) {
    var out = value;
    try {
      out = Uri.decodeFull(out);
    } catch (_) {}
    return out;
  }

  Future<List<String>> _fallbackMediaUrls(
    Uri uri,
    PlatformType platform,
  ) async {
    final out = <String>{};
    try {
      if (platform == PlatformType.twitter) {
        out.addAll(await _twitterFallback(uri));
      } else if (platform == PlatformType.tiktok) {
        out.addAll(await _tiktokFallback(uri));
      } else if (platform == PlatformType.instagram) {
        out.addAll(await _instagramFallback(uri));
      } else if (platform == PlatformType.facebook) {
        out.addAll(await _facebookFallback(uri));
      }
    } catch (_) {}
    return out.toList();
  }

  Future<List<String>> _twitterFallback(Uri uri) async {
    final id = _extractTwitterStatusId(uri);
    if (id == null) {
      return const [];
    }
    final endpoint = Uri.parse('https://api.vxtwitter.com/Twitter/status/$id');
    final res = await _dio.getUri<String>(
      endpoint,
      options: Options(responseType: ResponseType.plain),
    );
    if ((res.statusCode ?? 0) >= 400 || (res.data ?? '').isEmpty) {
      return const [];
    }

    final urls = <String>{};
    final data = jsonDecode(res.data!) as Map<String, dynamic>;

    void addUrl(dynamic raw) {
      if (raw is! String) {
        return;
      }
      final normalized = _normalizeUrl(_decodeMaybeJsonString(raw));
      if (_isMediaUrl(normalized)) {
        urls.add(normalized);
      }
    }

    final mediaUrls = data['mediaURLs'];
    if (mediaUrls is List) {
      for (final item in mediaUrls) {
        addUrl(item);
      }
    }

    final mediaExtended = data['media_extended'];
    if (mediaExtended is List) {
      for (final media in mediaExtended) {
        if (media is! Map) {
          continue;
        }
        addUrl(media['url']);
        final variants = media['variants'];
        if (variants is List) {
          for (final variant in variants) {
            if (variant is Map) {
              addUrl(variant['url']);
              addUrl(variant['src']);
            }
          }
        }
      }
    }

    return urls.toList();
  }

  String? _extractTwitterStatusId(Uri uri) {
    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'status') {
        final id = segments[i + 1];
        if (RegExp(r'^\d+$').hasMatch(id)) {
          return id;
        }
      }
    }
    return uri.queryParameters['id'];
  }

  Future<List<String>> _tiktokFallback(Uri uri) async {
    final urls = <String>{};

    try {
      final official = await TiktokScraper.getVideoInfo(uri.toString());
      for (final raw in official.downloadUrls) {
        if (raw.trim().isNotEmpty) {
          final normalized = _normalizeUrl(_decodeMaybeJsonString(raw));
          if (_isMediaUrl(normalized)) {
            urls.add(normalized);
          }
        }
      }
      if (urls.isNotEmpty) {
        return urls.toList();
      }
    } catch (_) {}

    try {
      final alt = await TiktokScraper.getVideoInfo(
        uri.toString(),
        source: ScrapeVideoSource.TikDownloader,
      );
      for (final raw in alt.downloadUrls) {
        if (raw.trim().isNotEmpty) {
          final normalized = _normalizeUrl(_decodeMaybeJsonString(raw));
          if (_isMediaUrl(normalized)) {
            urls.add(normalized);
          }
        }
      }
      if (urls.isNotEmpty) {
        return urls.toList();
      }
    } catch (_) {}

    final endpoint = Uri.https('www.tikwm.com', '/api/', {
      'url': uri.toString(),
    });
    final res = await _dio.getUri<String>(
      endpoint,
      options: Options(responseType: ResponseType.plain),
    );
    if ((res.statusCode ?? 0) >= 400 || (res.data ?? '').isEmpty) {
      return const [];
    }

    final data = jsonDecode(res.data!) as Map<String, dynamic>;
    if (data['code'] != 0 || data['data'] is! Map) {
      return const [];
    }
    final payload = data['data'] as Map;
    for (final key in ['play', 'hdplay', 'wmplay', 'playwm']) {
      final raw = payload[key];
      if (raw is String) {
        final normalized = _normalizeUrl(_decodeMaybeJsonString(raw));
        if (_isMediaUrl(normalized)) {
          urls.add(normalized);
        }
      }
    }
    return urls.toList();
  }

  Future<List<String>> _instagramFallback(Uri uri) async {
    final fromPackage = await extractInstagramUrls(uri.toString());
    if (fromPackage.isNotEmpty) {
      return fromPackage;
    }

    final dd = Uri(
      scheme: 'https',
      host: 'www.ddinstagram.com',
      path: uri.path,
      query: uri.query,
    );
    final html = await _fetchRawText(dd);
    return _findMediaUrls(html).toList();
  }

  Future<List<String>> _facebookFallback(Uri uri) async {
    final urls = <String>{};

    try {
      final post = await FacebookData.postFromUrl(uri.toString());
      for (final raw in [post.videoHdUrl, post.videoSdUrl]) {
        if (raw is String && raw.trim().isNotEmpty) {
          final normalized = _normalizeUrl(_decodeMaybeJsonString(raw));
          if (_isMediaUrl(normalized)) {
            urls.add(normalized);
          }
        }
      }
      if (urls.isNotEmpty) {
        return urls.toList();
      }
    } catch (_) {}

    final plugin = Uri.parse(
      'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(uri.toString())}',
    );
    final html = await _fetchRawText(plugin);
    urls.addAll(_findMediaUrls(html));
    return urls.toList();
  }

  Future<String> _fetchRawText(Uri uri) async {
    final res = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    if ((res.statusCode ?? 0) >= 400) {
      return '';
    }
    return (res.data ?? '').toString();
  }

  bool _isMediaUrl(String value) {
    if (!value.startsWith('http')) {
      return false;
    }
    final lower = value.toLowerCase();
    if (lower.contains('.mp4') ||
        lower.contains('.m3u8') ||
        lower.contains('.webm') ||
        lower.contains('.mov') ||
        lower.contains('.mkv')) {
      return true;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();
    final hostHint = _mediaHostHints.any(host.contains);
    final pathHint =
        path.contains('/video') ||
        path.contains('/vid/') ||
        path.contains('/playback') ||
        path.contains('/stream');
    final queryHint =
        query.contains('mime=video') ||
        query.contains('mime_type=video') ||
        query.contains('bytestart=') ||
        query.contains('byteend=');
    return hostHint && (pathHint || queryHint);
  }

  String _containerFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'm3u8';
    if (lower.contains('.webm')) return 'webm';
    if (lower.contains('.mov')) return 'mov';
    if (lower.contains('.mkv')) return 'mkv';
    return 'mp4';
  }

  String _qualityFromUrl(String url) {
    final lower = url.toLowerCase();
    final match = RegExp(r'(\d{3,4})p').firstMatch(lower);
    if (match != null) {
      return '${match.group(1)}p';
    }
    if (lower.contains('hd')) {
      return 'HD';
    }
    if (lower.contains('sd')) {
      return 'SD';
    }
    return 'Auto';
  }

  int _qualityRank(String quality) {
    final match = RegExp(r'(\d{3,4})').firstMatch(quality);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

class YouTubeExtractor implements VideoExtractor {
  final YoutubeExplode _youtube = YoutubeExplode();
  static const _youtubePathKinds = {'shorts', 'embed', 'live', 'v'};

  @override
  bool canHandle(Uri uri, PlatformType platform) =>
      platform == PlatformType.youtube;

  @override
  Future<VideoInfo> extract(Uri uri) async {
    final video = await _youtube.videos.get(_extractVideoId(uri));
    final manifest = await _youtube.videos.streamsClient.getManifest(video.id);
    final formats = <VideoFormat>[];

    for (final s in manifest.muxed) {
      final container = _container(s.container);
      formats.add(
        VideoFormat(
          id: 'yt_muxed_${s.tag}',
          label: '${s.qualityLabel} ($container)',
          url: s.url.toString(),
          container: container,
          quality: s.qualityLabel,
          hasAudio: true,
          isAdaptive: false,
        ),
      );
    }
    for (final s in manifest.videoOnly) {
      final container = _container(s.container);
      formats.add(
        VideoFormat(
          id: 'yt_adaptive_${s.tag}',
          label: '${s.videoQualityLabel} (video only)',
          url: s.url.toString(),
          container: container,
          quality: s.videoQualityLabel,
          hasAudio: false,
          isAdaptive: true,
        ),
      );
    }

    if (formats.isEmpty) {
      throw Exception('No downloadable stream found for this YouTube URL.');
    }
    formats.sort(
      (a, b) => _qualityRank(b.quality).compareTo(_qualityRank(a.quality)),
    );

    return VideoInfo(
      sourceUrl: uri.toString(),
      platform: PlatformType.youtube,
      title: video.title,
      thumbnailUrl: video.thumbnails.highResUrl,
      formats: formats,
    );
  }

  String _container(dynamic container) =>
      container.toString().split('.').last.toLowerCase();

  int _qualityRank(String quality) {
    final match = RegExp(r'(\d{3,4})').firstMatch(quality);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _extractVideoId(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be')) {
      if (uri.pathSegments.isEmpty) {
        throw Exception(
          'Invalid YouTube URL. Please provide a valid video link.',
        );
      }
      final id = uri.pathSegments.first;
      if (_isValidVideoId(id)) {
        return id;
      }
    }

    if (host.contains('youtube.com') || host.contains('youtube-nocookie.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && _isValidVideoId(v)) {
        return v;
      }

      final segments = uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.length >= 2 && _youtubePathKinds.contains(segments.first)) {
        final id = segments[1];
        if (_isValidVideoId(id)) {
          return id;
        }
      }
      if (segments.isNotEmpty && _isValidVideoId(segments.first)) {
        return segments.first;
      }
    }

    throw Exception(
      'Invalid YouTube video link. Try format like '
      'https://www.youtube.com/watch?v=VIDEO_ID or https://youtube.com/shorts/VIDEO_ID',
    );
  }

  bool _isValidVideoId(String value) =>
      RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value);
}
