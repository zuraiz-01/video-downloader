class AppVideoFormat {
  final String id;
  final String title;
  final String downloadUrl;
  final String fileName;
  final String type;

  AppVideoFormat({
    required this.id,
    required this.title,
    required this.downloadUrl,
    required this.fileName,
    this.type = 'file',
  });
}

class AppVideo {
  final String platform;
  final String title;
  final String author;
  final String note;
  final String thumbnail;
  final String downloadUrl;
  final String qualityText;
  final String fileName;
  final String sourceUrl;
  final Map<String, String>? _headers;
  final List<AppVideoFormat>? _formats;

  Map<String, String> get headers => _headers ?? const {};
  List<AppVideoFormat> get formats => _formats ?? const [];

  AppVideo({
    required this.platform,
    required this.title,
    required this.author,
    required this.note,
    required this.thumbnail,
    required this.downloadUrl,
    required this.qualityText,
    required this.fileName,
    required this.sourceUrl,
    Map<String, String>? headers,
    List<AppVideoFormat>? formats,
  }) : _headers = headers,
       _formats = formats;
}
