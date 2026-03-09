import 'dart:io';

import 'package:dio/dio.dart';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:facebook_video_download/facebook_video_download.dart';
import 'package:flutter_insta/flutter_insta.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:tiktok_scraper/enums.dart';
import 'package:tiktok_scraper/tiktok_scraper.dart';
import 'package:twitter_api_v2/twitter_api_v2.dart' as v2;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/app_video.dart';
import 'twitter_keys.dart';

class SimpleVideoService {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    ),
  );

  final FlutterInsta insta = FlutterInsta();

  Future<AppVideo> getVideoData(String url) async {
    final cleanUrl = _normalizeInputUrl(url);

    if (_isInstagramUrl(cleanUrl)) {
      return _instagramVideo(cleanUrl);
    }

    if (_isTikTokUrl(cleanUrl)) {
      return _tiktokVideo(cleanUrl);
    }

    if (_isFacebookUrl(cleanUrl)) {
      return _facebookVideo(cleanUrl);
    }

    if (_isYoutubeUrl(cleanUrl)) {
      return _youtubeVideo(cleanUrl);
    }

    if (_isTwitterUrl(cleanUrl)) {
      // Fixed: was calling _isXUrl but function name is _isTwitterUrl
      return _twitterVideo(cleanUrl);
    }

    if (_looksLikeDirectVideoFile(cleanUrl)) {
      final fileName = _fileNameFromUrl(cleanUrl, fallback: 'direct_video.mp4');

      return AppVideo(
        platform: 'Direct Link',
        title: 'Direct video file',
        author: 'Open link',
        note:
            'Direct file link mili hai. Isko dio se seedha download kiya jayega.',
        thumbnail: '',
        downloadUrl: cleanUrl,
        qualityText: 'Original file',
        fileName: fileName,
        sourceUrl: cleanUrl,
        headers: _headersFor(cleanUrl),
        formats: [
          _oneFormat(
            id: 'original',
            title: 'Original file',
            url: cleanUrl,
            fileName: fileName,
            type: 'file',
          ),
        ],
      );
    }

    throw Exception('Yeh link abhi supported nahin hai.');
  }

  Future<String> downloadVideo(
    AppVideo video,
    AppVideoFormat? format,
    void Function(int current, int total) onReceive,
  ) async {
    final selected = format ?? _defaultFormat(video);
    final tempFolder = await path_provider.getTemporaryDirectory();
    final path =
        '${tempFolder.path}${Platform.pathSeparator}${selected.fileName}';

    if (video.platform == 'YouTube') {
      await _downloadYoutubeVideo(video, selected, path, onReceive);
      return _moveToDownloads(path, selected.fileName);
    }

    await _downloadWithDio(video, selected, path, onReceive);
    return _moveToDownloads(path, selected.fileName);
  }

  Future<AppVideo> _instagramVideo(String url) async {
    final link = await insta.downloadReels(url);
    final fileName = 'instagram_${_safeFileStem('reel')}.mp4';

    return AppVideo(
      platform: 'Instagram',
      title: 'Instagram Reel',
      author: '@instagram',
      note: 'Package `flutter_insta` se reel link nikali gayi hai.',
      thumbnail: '',
      downloadUrl: link,
      qualityText: 'Reel video',
      fileName: fileName,
      sourceUrl: url,
      headers: _headersFor(link),
      formats: [
        _oneFormat(
          id: 'reel',
          title: 'Reel video',
          url: link,
          fileName: fileName,
          type: 'file',
        ),
      ],
    );
  }

  Future<AppVideo> _facebookVideo(String url) async {
    final normalizedUrl = _normalizeFacebookInputUrl(url);
    var hdLink = '';
    var sdLink = '';

    try {
      final post = await FacebookData.postFromUrl(normalizedUrl);
      hdLink = post.videoHdUrl ?? '';
      sdLink = post.videoSdUrl ?? '';
    } catch (_) {
      // Package parser brittle ho sakta hai. HTML fallback below.
    }

    if (hdLink.isEmpty && sdLink.isEmpty) {
      final extracted = await _extractFacebookVideoLinks(normalizedUrl);
      hdLink = extracted.$1;
      sdLink = extracted.$2;
    }

    final link = hdLink.isNotEmpty ? hdLink : sdLink;

    if (link.isEmpty) {
      throw Exception(
        'Facebook video link extract nahin hui. Public post link try karo.',
      );
    }

    final quality = hdLink.isNotEmpty ? 'HD ready' : 'SD ready';
    final formats = <AppVideoFormat>[];

    if (hdLink.isNotEmpty) {
      formats.add(
        _oneFormat(
          id: 'fb_hd',
          title: 'HD ready',
          url: hdLink,
          fileName: 'facebook_video_hd.mp4',
          type: 'file',
        ),
      );
    }

    if (sdLink.isNotEmpty && sdLink != hdLink) {
      formats.add(
        _oneFormat(
          id: 'fb_sd',
          title: 'SD ready',
          url: sdLink,
          fileName: 'facebook_video_sd.mp4',
          type: 'file',
        ),
      );
    }

    return AppVideo(
      platform: 'Facebook',
      title: 'Facebook Video',
      author: 'Public post',
      note:
          'Facebook parser + HTML fallback (www/m/mbasic) se stream nikali gayi hai.',
      thumbnail: '',
      downloadUrl: link,
      qualityText: quality,
      fileName: hdLink.isNotEmpty
          ? 'facebook_video_hd.mp4'
          : 'facebook_video_sd.mp4',
      sourceUrl: normalizedUrl,
      headers: _headersFor(link),
      formats: formats,
    );
  }

  Future<AppVideo> _tiktokVideo(String url) async {
    final normalizedUrl = _normalizeTikTokInputUrl(url);
    final resolvedUrl = await _resolveUrlWithRedirects(normalizedUrl);
    final sourceUrl = _normalizeTikTokInputUrl(resolvedUrl);

    try {
      final video = await TiktokScraper.getVideoInfo(
        sourceUrl,
        source: ScrapeVideoSource.OfficialSite,
      );
      final urls = _uniqueNonEmptyUrls(video.downloadUrls);

      if (urls.isNotEmpty) {
        final quality = video.defaultResolution.isEmpty
            ? 'Original'
            : video.defaultResolution;
        final title = video.description.isEmpty
            ? 'TikTok Video'
            : video.description;
        final author = video.author.username.isEmpty
            ? '@tiktok'
            : '@${video.author.username}';
        final fileName = _buildMp4NameFromTitle(
          title,
          fallback: 'tiktok_video',
        );

        return AppVideo(
          platform: 'TikTok',
          title: title,
          author: author,
          note: 'TikTok parser se direct play/download URLs nikali gayi hain.',
          thumbnail: video.thumbnail,
          downloadUrl: urls.first,
          qualityText: quality,
          fileName: fileName,
          sourceUrl: sourceUrl,
          headers: _headersFor(urls.first),
          formats: [
            _oneFormat(
              id: quality,
              title: quality,
              url: urls.first,
              fileName: fileName,
              type: 'file',
            ),
          ],
        );
      }
    } catch (_) {
      // Fallback below.
    }

    final fallback = await _extractTikTokFallback(sourceUrl);
    if (fallback.urls.isEmpty) {
      throw Exception(
        'TikTok video parse nahin hui. Public post/share link dubara try karo.',
      );
    }

    final title = fallback.title.isEmpty ? 'TikTok Video' : fallback.title;
    final fileName = _buildMp4NameFromTitle(title, fallback: 'tiktok_video');

    final formats = <AppVideoFormat>[];
    for (var i = 0; i < fallback.urls.length; i++) {
      final label = i == 0 ? 'Original' : 'Mirror ${i + 1}';
      formats.add(
        _oneFormat(
          id: 'tiktok_$i',
          title: label,
          url: fallback.urls[i],
          fileName: fileName,
          type: 'file',
        ),
      );
    }

    return AppVideo(
      platform: 'TikTok',
      title: title,
      author: fallback.author.isEmpty ? '@tiktok' : fallback.author,
      note:
          'Fallback parser (TikTok page + downloader endpoint) use hua kyun ke official item path fail hui.',
      thumbnail: fallback.thumbnail,
      downloadUrl: fallback.urls.first,
      qualityText: formats.first.title,
      fileName: fileName,
      sourceUrl: fallback.sourceUrl,
      headers: _headersFor(fallback.urls.first),
      formats: formats,
    );
  }

  Future<AppVideo> _youtubeVideo(String url) async {
    final videoId = _youtubeIdFromUrl(url);
    if (videoId.isEmpty) {
      throw Exception('YouTube link sahi nahin hai.');
    }

    final sourceUrl = _canonicalYoutubeUrl(videoId);
    final yt = YoutubeExplode();

    try {
      final video = await yt.videos.get(videoId);
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final formats = <AppVideoFormat>[];

      final muxedStreams = manifest.muxed.toList()
        ..sort(
          (a, b) =>
              b.videoResolution.height.compareTo(a.videoResolution.height),
        );

      for (final stream in muxedStreams) {
        formats.add(
          _oneFormat(
            id: 'muxed_${stream.tag}',
            title:
                '${stream.qualityLabel} ${stream.container.name.toUpperCase()}',
            url: stream.url.toString(),
            fileName: _buildYoutubeFileName(
              video.title,
              stream.qualityLabel,
              stream.container.name,
            ),
            type: 'youtube_muxed',
          ),
        );
      }

      final audioOnlyStreams = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      for (final stream in audioOnlyStreams) {
        final kbps = (stream.bitrate.bitsPerSecond / 1000).round();
        formats.add(
          _oneFormat(
            id: 'audio_${stream.tag}',
            title: 'Audio $kbps kbps (${stream.container.name.toUpperCase()})',
            url: stream.url.toString(),
            fileName: _buildAudioFileName(
              video.title,
              kbps,
              stream.container.name,
            ),
            type: 'youtube_audio',
          ),
        );
      }

      if (formats.isEmpty) {
        throw Exception('YouTube resolution list nahin mili.');
      }

      final preferred = formats.firstWhere(
        (f) => f.type == 'youtube_muxed',
        orElse: () => formats.first,
      );

      return AppVideo(
        platform: 'YouTube',
        title: video.title,
        author: video.author,
        note:
            'Sirf muxed video (audio + video) aur audio-only options dikhaye gaye hain. Video-only hidden rakhe gaye hain taake silent file na aaye.',
        thumbnail: video.thumbnails.maxResUrl,
        downloadUrl: preferred.downloadUrl,
        qualityText: preferred.title,
        fileName: preferred.fileName,
        sourceUrl: sourceUrl,
        headers: _headersFor(sourceUrl),
        formats: formats,
      );
    } finally {
      yt.close();
    }
  }

  Future<AppVideo> _twitterVideo(String url) async {
    if (!TwitterKeys.ready) {
      throw Exception(
        'X video ke liye `lib/app/services/twitter_keys.dart` me bearer token dalo.',
      );
    }

    final tweetId = _tweetId(url);
    if (tweetId.isEmpty) {
      throw Exception('Tweet id read nahin ho rahi.');
    }

    final twitter = v2.TwitterApi(
      bearerToken: TwitterKeys.bearerToken,
      timeout: const Duration(seconds: 20),
      retryConfig: v2.RetryConfig.ofRegularIntervals(
        maxAttempts: 2,
        intervalInSeconds: 2,
      ),
    );

    final response = await twitter.tweetsService.lookupById(
      tweetId: tweetId,
      expansions: [
        v2.TweetExpansion.attachmentsMediaKeys,
        v2.TweetExpansion.authorId,
      ],
      tweetFields: [v2.TweetField.authorId],
      mediaFields: [
        v2.MediaField.previewImageUrl,
        v2.MediaField.type,
        v2.MediaField.variants,
      ],
      userFields: [v2.UserField.username, v2.UserField.name],
    );

    final mediaList = response.includes?.media ?? [];
    final videoMedia = mediaList.firstWhere(
      (item) => item.variants != null && item.variants!.isNotEmpty,
      orElse: () => throw Exception('X video media nahin mili.'),
    );

    final variants =
        videoMedia.variants!
            .where((item) => item.contentType.toLowerCase().contains('mp4'))
            .toList()
          ..sort((a, b) => (b.bitRate ?? 0).compareTo(a.bitRate ?? 0));

    if (variants.isEmpty) {
      throw Exception('X video variants nahin mili.');
    }

    final best = variants.first;
    final kbps = ((best.bitRate ?? 0) / 1000).round();
    final titleText = response.data.text.trim();
    final title = titleText.isEmpty ? 'X Video' : titleText;
    final fileName = _buildMp4NameFromTitle(title, fallback: 'x_video');

    String author = '@tweet';
    final users = response.includes?.users ?? [];
    if (users.isNotEmpty) {
      final username = users.first.username;
      if (username != null && username.isNotEmpty) {
        author = '@$username';
      }
    }

    return AppVideo(
      platform: 'X',
      title: title,
      author: author,
      note:
          'Package `twitter_api_v2` se tweet media read ki gayi hai. Is path ko bearer token chahiye hota hai.',
      thumbnail: videoMedia.previewImageUrl ?? '',
      downloadUrl: best.url,
      qualityText: '$kbps kbps',
      fileName: fileName,
      sourceUrl: url,
      headers: _headersFor(best.url),
      formats: [
        _oneFormat(
          id: 'x_$kbps',
          title: '$kbps kbps',
          url: best.url,
          fileName: fileName,
          type: 'file',
        ),
      ],
    );
  }

  Future<void> _downloadWithDio(
    AppVideo video,
    AppVideoFormat format,
    String path,
    void Function(int current, int total) onReceive,
  ) async {
    final headers = {
      ...dio.options.headers,
      ..._headersFor(format.downloadUrl),
    };

    try {
      await dio.download(
        format.downloadUrl,
        path,
        onReceiveProgress: onReceive,
        deleteOnError: true,
        options: Options(
          headers: headers,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (code) => code != null && code < 500,
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) {
        throw Exception(
          '${video.platform} server ne request block kar di (403). Fresh public link try karo.',
        );
      }
      if (status == 404) {
        throw Exception(
          '${video.platform} media URL expire ya remove ho gayi (404).',
        );
      }
      if (status == 429) {
        throw Exception(
          '${video.platform} ne zyada requests ki wajah se block kiya (429).',
        );
      }
      rethrow;
    }
  }

  Future<void> _downloadYoutubeVideo(
    AppVideo video,
    AppVideoFormat format,
    String path,
    void Function(int current, int total) onReceive,
  ) async {
    final yt = YoutubeExplode();

    try {
      final videoId = _youtubeIdFromUrl(video.sourceUrl);
      if (videoId.isEmpty) {
        throw Exception('YouTube link sahi nahin hai.');
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = _pickYoutubeStream(manifest, format);
      final stream = yt.videos.streamsClient.get(streamInfo);
      final file = File(path);
      final sink = file.openWrite();
      var received = 0;
      final total = streamInfo.size.totalBytes;

      await for (final chunk in stream) {
        received += chunk.length;
        sink.add(chunk);
        onReceive(received, total);
      }

      await sink.flush();
      await sink.close();
    } catch (e) {
      throw Exception('YouTube download start nahin hui: $e');
    } finally {
      yt.close();
    }
  }

  Future<Directory> _saveFolder() async {
    if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (await androidDownloads.exists()) {
        return androidDownloads;
      }
    }

    try {
      return getDownloadDirectory();
    } catch (_) {}

    return path_provider.getApplicationDocumentsDirectory();
  }

  AppVideoFormat _defaultFormat(AppVideo video) {
    if (video.formats.isNotEmpty) {
      final muxed = video.formats.where((f) => f.type == 'youtube_muxed');
      if (muxed.isNotEmpty) return muxed.first;
      return video.formats.first;
    }

    return _oneFormat(
      id: video.qualityText,
      title: video.qualityText,
      url: video.downloadUrl,
      fileName: video.fileName,
      type: 'file',
    );
  }

  bool _looksLikeDirectVideoFile(String text) {
    final uri = Uri.tryParse(text.trim());
    final path = (uri?.path ?? text).toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.mkv');
  }

  Map<String, String> _headersFor(String pageUrl) {
    final uri = Uri.tryParse(pageUrl);
    if (uri == null || uri.host.isEmpty) {
      return const {};
    }

    final host = uri.host.toLowerCase();

    if (host.contains('facebook.com') ||
        host.contains('fbcdn.net') ||
        host == 'fb.watch') {
      return {
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://www.facebook.com',
        'Referer': 'https://www.facebook.com/',
      };
    }

    if (host.contains('tiktokcdn') || host.contains('tiktok.com')) {
      return {
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://www.tiktok.com',
        'Referer': 'https://www.tiktok.com/',
      };
    }

    if (host.contains('cdninstagram') || host.contains('instagram.com')) {
      return {
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://www.instagram.com',
        'Referer': 'https://www.instagram.com/',
      };
    }

    if (host.contains('twimg.com') ||
        host.contains('x.com') ||
        host.contains('twitter.com')) {
      return {
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Origin': 'https://x.com',
        'Referer': 'https://x.com/',
      };
    }

    final origin = '${uri.scheme}://${uri.host}';
    return {
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Origin': origin,
      'Referer': origin,
    };
  }

  String _normalizeInputUrl(String text) {
    final url = text.trim();

    if (_isYoutubeUrl(url)) {
      final videoId = _youtubeIdFromUrl(url);
      if (videoId.isNotEmpty) {
        return _canonicalYoutubeUrl(videoId);
      }
    }

    if (_isFacebookUrl(url)) {
      return _normalizeFacebookInputUrl(url);
    }

    if (_isTikTokUrl(url)) {
      return _normalizeTikTokInputUrl(url);
    }

    return url;
  }

  bool _isInstagramUrl(String text) =>
      _hostMatches(text, const ['instagram.com']);

  bool _isFacebookUrl(String text) =>
      _hostMatches(text, const ['facebook.com', 'fb.watch']);

  bool _isTikTokUrl(String text) => _hostMatches(text, const ['tiktok.com']);

  bool _isYoutubeUrl(String text) =>
      _hostMatches(text, const ['youtube.com', 'youtu.be']);

  bool _isTwitterUrl(String text) =>
      _hostMatches(text, const ['twitter.com', 'x.com']);

  bool _hostMatches(String text, List<String> domains) {
    final uri = Uri.tryParse(text.trim());
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;

    for (final domain in domains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  String _normalizeFacebookInputUrl(String text, {bool preferWww = true}) {
    final value = text.trim();
    if (value.isEmpty) return value;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;

    final host = uri.host.toLowerCase();
    if (!host.contains('facebook.com') && host != 'fb.watch') {
      return value;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    const trackingKeys = {
      '__cft__',
      '__tn__',
      'mibextid',
      'refsrc',
      'sfnsn',
      'rdid',
      '_rdr',
    };
    query.removeWhere((key, _) => trackingKeys.contains(key.toLowerCase()));

    String normalizedHost;
    if (host == 'fb.watch') {
      normalizedHost = 'fb.watch';
    } else if (preferWww) {
      normalizedHost = 'www.facebook.com';
    } else {
      normalizedHost = uri.host;
    }

    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    final cleanedPath = segments.isEmpty ? '/' : '/${segments.join('/')}';

    return Uri(
      scheme: 'https',
      host: normalizedHost,
      path: cleanedPath,
      queryParameters: query.isEmpty ? null : query,
      fragment: null,
    ).toString();
  }

  String _normalizeTikTokInputUrl(String text) {
    final value = text.trim();
    if (value.isEmpty) return value;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;

    final host = uri.host.toLowerCase();
    if (!host.contains('tiktok.com')) {
      return value;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    const trackingKeys = {
      '_r',
      '_t',
      'checksum',
      'is_copy_url',
      'is_from_webapp',
      'sender_device',
      'share_app_id',
      'share_iid',
      'share_link_id',
      'timestamp',
      'u_code',
      'social_share_type',
      'utm_source',
      'utm_medium',
      'utm_campaign',
    };
    query.removeWhere((key, _) => trackingKeys.contains(key.toLowerCase()));

    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    final cleanedPath = segments.isEmpty ? '/' : '/${segments.join('/')}';

    return Uri(
      scheme: 'https',
      host: uri.host,
      path: cleanedPath,
      queryParameters: query.isEmpty ? null : query,
      fragment: null,
    ).toString();
  }

  String _canonicalYoutubeUrl(String videoId) {
    return 'https://www.youtube.com/watch?v=$videoId';
  }

  String _youtubeIdFromUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri == null) return '';

    final host = uri.host.toLowerCase();
    final watchId = uri.queryParameters['v'];
    if (watchId != null && watchId.isNotEmpty) {
      return watchId;
    }

    final parts = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) return '';

    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return parts.first;
    }

    const namedPaths = {'shorts', 'embed', 'live', 'v'};
    if (parts.length >= 2 && namedPaths.contains(parts.first)) {
      return parts[1];
    }

    final match = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:shorts\/|embed\/|live\/|watch\?v=|v\/))([A-Za-z0-9_-]{6,})',
    ).firstMatch(value);

    return match?.group(1) ?? '';
  }

  AppVideoFormat _oneFormat({
    required String id,
    required String title,
    required String url,
    required String fileName,
    required String type,
  }) {
    return AppVideoFormat(
      id: id,
      title: title,
      downloadUrl: url,
      fileName: fileName,
      type: type,
    );
  }

  StreamInfo _pickYoutubeStream(
    StreamManifest manifest,
    AppVideoFormat format,
  ) {
    if (format.type == 'youtube_audio') {
      return manifest.audioOnly.firstWhere(
        (item) => format.id == 'audio_${item.tag}',
        orElse: () => manifest.audioOnly.withHighestBitrate(),
      );
    }

    return manifest.muxed.firstWhere(
      (item) => format.id == 'muxed_${item.tag}',
      orElse: () {
        final sorted = manifest.muxed.toList()
          ..sort(
            (a, b) =>
                b.videoResolution.height.compareTo(a.videoResolution.height),
          );
        return sorted.first;
      },
    );
  }

  Future<String> _moveToDownloads(String tempPath, String fileName) async {
    final tempFile = File(tempPath);
    if (!await tempFile.exists()) {
      throw Exception('Downloaded file temp folder me nahin mili.');
    }

    final folder = await _saveFolder();
    final safeName = await _uniqueFileName(folder.path, fileName);

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await copyFileIntoDownloadFolder(tempPath, safeName);
        await tempFile.delete();
        return '${folder.path}${Platform.pathSeparator}$safeName';
      } catch (_) {
        final finalPath = '${folder.path}${Platform.pathSeparator}$safeName';
        final finalFile = File(finalPath);
        await finalFile.parent.create(recursive: true);
        await tempFile.copy(finalPath);
        await tempFile.delete();
        return finalPath;
      }
    }

    final finalPath = '${folder.path}${Platform.pathSeparator}$safeName';
    final finalFile = File(finalPath);
    await finalFile.parent.create(recursive: true);
    await tempFile.copy(finalPath);
    await tempFile.delete();
    return finalPath;
  }

  Future<String> _uniqueFileName(String folderPath, String fileName) async {
    final sanitized = _sanitizeFileName(fileName);
    final dot = sanitized.lastIndexOf('.');
    final hasExt = dot > 0;
    final name = hasExt ? sanitized.substring(0, dot) : sanitized;
    final ext = hasExt ? sanitized.substring(dot) : '';
    var candidate = sanitized;
    var index = 1;

    while (await File(
      '$folderPath${Platform.pathSeparator}$candidate',
    ).exists()) {
      candidate = '${name}_$index$ext';
      index++;
    }

    return candidate;
  }

  String _tweetId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return '';

    final parts = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    for (var i = 0; i < parts.length - 1; i++) {
      if (parts[i].toLowerCase() == 'status') {
        final id = parts[i + 1];
        if (RegExp(r'^\d+$').hasMatch(id)) {
          return id;
        }
      }
    }

    final match = RegExp(r'status/(\d+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<String> _resolveUrlWithRedirects(String url) async {
    try {
      final response = await dio.get<String>(
        url,
        options: Options(
          headers: {
            ...dio.options.headers,
            ..._headersFor(url),
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      final realUrl = response.realUri.toString();
      return realUrl.isEmpty ? url : realUrl;
    } catch (_) {
      return url;
    }
  }

  Future<
    ({
      String sourceUrl,
      List<String> urls,
      String title,
      String author,
      String thumbnail,
    })
  >
  _extractTikTokFallback(String url) async {
    final resolved = await _resolveUrlWithRedirects(url);
    final sourceUrl = _normalizeTikTokInputUrl(resolved);
    final urls = <String>[];
    var title = '';
    var author = '';
    var thumbnail = '';

    try {
      final fromApi = await _extractTikTokDownloaderLinks(sourceUrl);
      urls.addAll(fromApi);
    } catch (_) {}

    try {
      final page = await dio.get<String>(
        sourceUrl,
        options: Options(
          headers: {
            ...dio.options.headers,
            ..._headersFor(sourceUrl),
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      final decoded = _decodeTikTokBody(page.data ?? '');

      final pageUrls = _findAll(decoded, [
        r'"downloadAddr":"([^"]+)"',
        r'"playAddr":"([^"]+)"',
        r'"playAddrH264":"([^"]+)"',
        r'"play_url":"([^"]+)"',
        r'''property=["']og:video["'][^>]*content=["']([^"']+)''',
        r'''name=["']twitter:player:stream["'][^>]*content=["']([^"']+)''',
      ]).map(_cleanTikTokUrl).toList();

      urls.addAll(pageUrls);

      title = _cleanTikTokText(
        _findFirst(decoded, [
          r'"desc":"([^"]+)"',
          r'"description":"([^"]+)"',
          r'''property=["']og:description["'][^>]*content=["']([^"']+)''',
        ]),
      );

      final authorValue = _cleanTikTokText(
        _findFirst(decoded, [
          r'"uniqueId":"([^"]+)"',
          r'"authorName":"([^"]+)"',
          r'"nickname":"([^"]+)"',
        ]),
      );

      author = authorValue.isEmpty || authorValue.startsWith('@')
          ? authorValue
          : '@$authorValue';

      thumbnail = _cleanTikTokUrl(
        _findFirst(decoded, [
          r'"cover":"([^"]+)"',
          r'"dynamicCover":"([^"]+)"',
          r'''property=["']og:image["'][^>]*content=["']([^"']+)''',
        ]),
      );
    } catch (_) {}

    return (
      sourceUrl: sourceUrl,
      urls: _uniqueNonEmptyUrls(urls),
      title: title,
      author: author,
      thumbnail: thumbnail,
    );
  }

  Future<List<String>> _extractTikTokDownloaderLinks(String url) async {
    final response = await dio.post<Map<String, dynamic>>(
      ScrapeVideoSource.TikDownloader.url,
      data: FormData.fromMap({'q': url, 'lang': 'en'}),
      options: Options(
        headers: {
          ...dio.options.headers,
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://tikdownloader.io',
          'Referer': 'https://tikdownloader.io/',
        },
        followRedirects: true,
        validateStatus: (code) => code != null && code < 500,
      ),
    );

    final html = response.data?['data']?.toString() ?? '';
    if (html.isEmpty) {
      return const [];
    }

    final urls = _findAll(html, [
      r'''href=["']([^"']+)["'][^>]*class=["'][^"']*dl-success[^"']*["']''',
      r'''href=["']([^"']+)["'][^>]*>\s*Download MP4''',
    ]).map(_cleanTikTokUrl).toList();

    return _uniqueNonEmptyUrls(urls);
  }

  List<String> _uniqueNonEmptyUrls(List<String> input) {
    final result = <String>[];
    final seen = <String>{};

    for (final value in input) {
      final cleaned = value.trim();
      if (cleaned.isEmpty || seen.contains(cleaned)) {
        continue;
      }

      if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
        seen.add(cleaned);
        result.add(cleaned);
      }
    }

    return result;
  }

  Future<(String, String)> _extractFacebookVideoLinks(String url) async {
    final queue = <String>[];
    final seen = <String>{};

    void addCandidate(String value) {
      final normalized = _normalizeFacebookInputUrl(value, preferWww: false);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }

      if (!queue.contains(normalized)) {
        queue.add(normalized);
      }
    }

    addCandidate(url);
    addCandidate(_swapFacebookHost(url, 'm.facebook.com'));
    addCandidate(_swapFacebookHost(url, 'mbasic.facebook.com'));
    addCandidate(
      'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(url)}',
    );

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!seen.add(current)) {
        continue;
      }

      try {
        final response = await dio.get<String>(
          current,
          options: Options(
            headers: {
              ...dio.options.headers,
              ..._headersFor(current),
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            responseType: ResponseType.plain,
            followRedirects: true,
            validateStatus: (code) => code != null && code < 500,
          ),
        );

        final body = response.data ?? '';
        final decoded = _decodeFacebookBody(body);

        final hd = _findFirst(decoded, [
          r'"browser_native_hd_url":"([^"]+)"',
          r'"playable_url_quality_hd":"([^"]+)"',
          r'"hd_src_no_ratelimit":"([^"]+)"',
          r'"hd_src":"([^"]+)"',
          r'hd_src:"([^"]+)"',
          r'''property=["']og:video:secure_url["'][^>]*content=["']([^"']+)''',
          r'''property=["']og:video["'][^>]*content=["']([^"']+)''',
        ]);

        final sd = _findFirst(decoded, [
          r'"browser_native_sd_url":"([^"]+)"',
          r'"playable_url":"([^"]+)"',
          r'"playable_url_quality_sd":"([^"]+)"',
          r'"sd_src_no_ratelimit":"([^"]+)"',
          r'"sd_src":"([^"]+)"',
          r'sd_src:"([^"]+)"',
          r'''property=["']og:video:url["'][^>]*content=["']([^"']+)''',
          r'''name=["']twitter:player:stream["'][^>]*content=["']([^"']+)''',
        ]);

        if (hd.isNotEmpty || sd.isNotEmpty) {
          return (_cleanFacebookUrl(hd), _cleanFacebookUrl(sd));
        }

        final redirected = response.realUri.toString();
        if (_isFacebookUrl(redirected) && redirected != current) {
          addCandidate(redirected);
          addCandidate(_swapFacebookHost(redirected, 'm.facebook.com'));
          addCandidate(_swapFacebookHost(redirected, 'mbasic.facebook.com'));
        }
      } catch (_) {}
    }

    return ('', '');
  }

  String _decodeFacebookBody(String input) {
    return input
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u003A', ':')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u003D', '=')
        .replaceAll('&amp;', '&');
  }

  String _findFirst(String input, List<String> patterns) {
    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(input);
      final value = match?.group(1) ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  List<String> _findAll(String input, List<String> patterns) {
    final result = <String>[];

    for (final pattern in patterns) {
      final matches = RegExp(pattern, caseSensitive: false).allMatches(input);
      for (final match in matches) {
        final value = match.group(1) ?? '';
        if (value.isNotEmpty) {
          result.add(value);
        }
      }
    }

    return result;
  }

  String _decodeTikTokBody(String input) {
    return input
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u003A', ':')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u003D', '=')
        .replaceAll('&amp;', '&');
  }

  String _cleanTikTokText(String value) {
    if (value.isEmpty) return '';
    return _decodeTikTokBody(value).replaceAll(r'\"', '"').trim();
  }

  String _cleanTikTokUrl(String value) {
    if (value.isEmpty) return '';
    final cleaned = _decodeTikTokBody(value).replaceAll(r'\\', '');
    try {
      return Uri.decodeFull(cleaned);
    } catch (_) {
      return cleaned;
    }
  }

  String _cleanFacebookUrl(String value) {
    if (value.isEmpty) return '';
    try {
      return Uri.decodeFull(value.replaceAll(r'\\', ''));
    } catch (_) {
      return value.replaceAll(r'\\', '');
    }
  }

  String _swapFacebookHost(String input, String host) {
    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty) return '';

    final currentHost = uri.host.toLowerCase();
    if (!currentHost.contains('facebook.com')) {
      return '';
    }

    return uri.replace(scheme: 'https', host: host, fragment: null).toString();
  }

  String _safeFileStem(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    if (cleaned.isEmpty) return 'video';
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  String _sanitizeFileName(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'video.mp4';

    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
  }

  String _buildMp4NameFromTitle(String title, {required String fallback}) {
    final stem = _safeFileStem(title);
    return '${stem.isEmpty ? fallback : stem}.mp4';
  }

  String _buildAudioFileName(String title, int kbps, String extension) {
    final stem = _safeFileStem(title);
    return '${stem}_audio_${kbps}kbps.$extension';
  }

  String _buildYoutubeFileName(
    String title,
    String qualityLabel,
    String extension,
  ) {
    final stem = _safeFileStem(title);
    final quality = _safeFileStem(qualityLabel);
    return '${stem}_$quality.$extension';
  }

  String _fileNameFromUrl(String url, {required String fallback}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return fallback;
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (segments.isEmpty) return fallback;
    final last = segments.last;
    if (last.isEmpty) return fallback;
    return _sanitizeFileName(last);
  }
}
