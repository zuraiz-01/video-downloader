enum PlatformType { youtube, direct, unknown }

extension PlatformTypeX on PlatformType {
  String get label => switch (this) {
    PlatformType.youtube => 'YouTube',
    PlatformType.direct => 'Direct Link',
    PlatformType.unknown => 'Unknown',
  };
}

class VideoFormat {
  const VideoFormat({
    required this.id,
    required this.label,
    required this.url,
    required this.container,
    required this.quality,
    required this.hasAudio,
    required this.isAdaptive,
  });

  final String id, label, url, container, quality;
  final bool hasAudio, isAdaptive;
}

class VideoInfo {
  const VideoInfo({
    required this.sourceUrl,
    required this.platform,
    required this.title,
    required this.formats,
    this.thumbnailUrl,
  });

  final String sourceUrl, title;
  final PlatformType platform;
  final List<VideoFormat> formats;
  final String? thumbnailUrl;
}
