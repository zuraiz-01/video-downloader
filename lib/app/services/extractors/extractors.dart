import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../models/video_models.dart';

class UrlClassifier {
  static const _directExt = ['.mp4', '.mkv', '.mov', '.webm', '.m3u8'];

  PlatformType classify(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('youtu.be') || host.contains('youtube.com')) {
      return PlatformType.youtube;
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
  final _extractors = <VideoExtractor>[YouTubeExtractor(), DirectExtractor()];

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
    throw Exception(lastError?.toString() ?? 'Unable to extract media links.');
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
