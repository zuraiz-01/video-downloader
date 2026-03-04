import 'dart:convert';

import 'package:http/http.dart' as http;

class InstaVideoDownloader {
  InstaVideoDownloader({http.Client? client, this.cookie})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? cookie;

  Future<List<String>> extractUrls(String input) async {
    final shortcode = _shortcodeFromInput(input);
    if (shortcode == null) {
      return const [];
    }

    final baseUrl = _buildInputUrl(input, shortcode);
    final urls = <String>{};

    final body = await _getText(baseUrl, withCookie: true);
    urls.addAll(_extractMediaUrls(body));

    if (urls.isEmpty) {
      final embedBody = await _getText(
        'https://www.instagram.com/reel/$shortcode/embed',
        withCookie: false,
      );
      urls.addAll(_extractMediaUrls(embedBody));
    }

    if (urls.isEmpty) {
      final jsonBody = await _getText(
        'https://www.instagram.com/p/$shortcode/?__a=1&__d=dis',
        withCookie: true,
        acceptJson: true,
      );
      urls.addAll(_extractFromJson(jsonBody));
      urls.addAll(_extractMediaUrls(jsonBody));
    }

    return urls.map(_normalize).where(_looksLikeMedia).toSet().toList();
  }

  Future<String> _getText(
    String url, {
    required bool withCookie,
    bool acceptJson = false,
  }) async {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/122.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': acceptJson
          ? 'application/json,text/plain,*/*'
          : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    };
    if (withCookie && cookie != null && cookie!.trim().isNotEmpty) {
      headers['Cookie'] = cookie!;
    }

    try {
      final response = await _client.get(Uri.parse(url), headers: headers);
      return response.body;
    } catch (_) {
      return '';
    }
  }

  String? _shortcodeFromInput(String input) {
    final trimmed = input.trim();
    final fromUrl = RegExp(
      r'(?:instagram\.com\/(?:p|reel|tv)\/)([a-zA-Z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fromUrl != null) {
      return fromUrl.group(1);
    }
    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  String _buildInputUrl(String input, String shortcode) {
    final trimmed = input.trim();
    if (trimmed.contains('instagram.com/')) {
      return trimmed;
    }
    return 'https://www.instagram.com/reel/$shortcode/';
  }

  List<String> _extractMediaUrls(String body) {
    if (body.trim().isEmpty) {
      return const [];
    }

    final urls = <String>{};
    final patterns = <RegExp>[
      RegExp(r'<meta property="og:video" content="(.*?)"'),
      RegExp(r'"video_url"\s*:\s*"(.*?)"'),
      RegExp(r'"contentUrl"\s*:\s*"(.*?)"'),
      RegExp(r'"playback_url"\s*:\s*"(.*?)"'),
      RegExp(r'"url"\s*:\s*"(https?:\\?/\\?/[^"]+)"'),
      RegExp(r'https?:\\?/\\?/[^<>\s]+\.m3u8[^<>\s]*', caseSensitive: false),
      RegExp(r'https?:\\?/\\?/[^<>\s]+\.mp4[^<>\s]*', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(body)) {
        final raw = match.group(1) ?? match.group(0) ?? '';
        if (raw.trim().isNotEmpty) {
          urls.add(raw);
        }
      }
    }
    return urls.toList();
  }

  List<String> _extractFromJson(String text) {
    if (text.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      final urls = <String>{};

      void walk(dynamic value) {
        if (value is Map) {
          for (final entry in value.entries) {
            final key = entry.key.toString().toLowerCase();
            if ((key.contains('video') || key.contains('playback')) &&
                entry.value is String) {
              urls.add(entry.value as String);
            } else {
              walk(entry.value);
            }
          }
        } else if (value is List) {
          for (final item in value) {
            walk(item);
          }
        }
      }

      walk(decoded);
      return urls.toList();
    } catch (_) {
      return const [];
    }
  }

  String _normalize(String value) {
    var out = value.trim();
    out = out.replaceAll(r'\/', '/');
    out = out.replaceAll(r'\u002F', '/');
    out = out.replaceAll(r'\\/', '/');
    out = out.replaceAll('&amp;', '&');
    out = out.replaceAll(RegExp("^[\"']+|[\"',\\\\]+\$"), '');
    return out;
  }

  bool _looksLikeMedia(String value) {
    final lower = value.toLowerCase();
    return value.startsWith('http') &&
        (lower.contains('.mp4') ||
            lower.contains('.m3u8') ||
            lower.contains('cdninstagram.com') ||
            lower.contains('scontent.cdninstagram.com'));
  }
}

Future<List<String>> extractInstagramUrls(
  String input, {
  String? cookie,
}) async {
  final downloader = InstaVideoDownloader(cookie: cookie);
  return downloader.extractUrls(input);
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    return;
  }
  final urls = await extractInstagramUrls(args.first);
  if (urls.isNotEmpty) {
    // ignore: avoid_print
    print(urls.first);
  }
}
