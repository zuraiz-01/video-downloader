import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/video_models.dart';
import '../services/downloader/downloader_service.dart';
import '../services/extractors/extractors.dart';
import '../utils/file_name_sanitizer.dart';

class DownloadController extends GetxController {
  DownloadController(this._registry, this._downloader);

  final ExtractorRegistry _registry;
  final DownloaderService _downloader;

  final TextEditingController linkController = TextEditingController();
  final RxBool isAnalyzing = false.obs;
  final RxBool isDownloading = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxnString errorMessage = RxnString();
  final RxString statusMessage = ''.obs;
  final Rxn<VideoInfo> videoInfo = Rxn<VideoInfo>();
  final RxnString selectedFormatId = RxnString();

  VideoFormat? get selectedFormat {
    final info = videoInfo.value;
    final id = selectedFormatId.value;
    if (info == null || id == null) {
      return null;
    }
    for (final format in info.formats) {
      if (format.id == id) {
        return format;
      }
    }
    return null;
  }

  Future<void> analyze() async {
    final url = linkController.text.trim();
    if (url.isEmpty) {
      errorMessage.value = 'Please paste a valid video/reel URL.';
      return;
    }

    _resetAnalyzeState();
    isAnalyzing.value = true;
    try {
      final info = await _registry.extract(url);
      videoInfo.value = info;
      selectedFormatId.value = _pickDefaultFormat(info.formats)?.id;
      statusMessage.value =
          'Link analyzed: ${info.platform.label}. Select quality and start download.';
    } catch (error) {
      errorMessage.value = _prettyError(error);
    } finally {
      isAnalyzing.value = false;
    }
  }

  Future<void> downloadSelected() async {
    final info = videoInfo.value;
    final format = selectedFormat;
    if (info == null || format == null) {
      errorMessage.value = 'Please analyze URL and select a quality first.';
      return;
    }

    isDownloading.value = true;
    progress.value = 0;
    errorMessage.value = null;

    try {
      final output = await _downloader.download(
        url: format.url,
        fileName: _createFileName(info, format),
        sourceUrl: info.sourceUrl,
        onProgress: (value) => progress.value = value,
      );

      if (kIsWeb) {
        statusMessage.value = 'Download started in browser.';
      } else {
        statusMessage.value = 'Downloaded to: $output';
      }
    } catch (error) {
      errorMessage.value = _prettyError(error);
    } finally {
      isDownloading.value = false;
    }
  }

  void pickFormat(String? id) => selectedFormatId.value = id;

  void _resetAnalyzeState() {
    progress.value = 0;
    errorMessage.value = null;
    statusMessage.value = '';
    videoInfo.value = null;
    selectedFormatId.value = null;
  }

  String _createFileName(VideoInfo info, VideoFormat format) {
    final ext = format.container.isEmpty ? 'mp4' : format.container;
    final raw = '${info.title}_${format.quality}.${ext.toLowerCase()}';
    return sanitizeFileName(raw);
  }

  VideoFormat? _pickDefaultFormat(List<VideoFormat> formats) {
    if (formats.isEmpty) {
      return null;
    }

    VideoFormat best = formats.first;
    for (final format in formats.skip(1)) {
      if (_isBetterChoice(format, best)) {
        best = format;
      }
    }
    return best;
  }

  bool _isBetterChoice(VideoFormat candidate, VideoFormat current) {
    if (candidate.hasAudio != current.hasAudio) {
      return candidate.hasAudio;
    }
    return _qualityRank(candidate.quality) > _qualityRank(current.quality);
  }

  int _qualityRank(String quality) {
    final match = RegExp(r'(\d{3,4})').firstMatch(quality);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _prettyError(Object error) {
    final value = error.toString();
    if (value.startsWith('Exception: ')) {
      return value.replaceFirst('Exception: ', '');
    }
    return value;
  }

  @override
  void onClose() {
    linkController.dispose();
    super.onClose();
  }
}
