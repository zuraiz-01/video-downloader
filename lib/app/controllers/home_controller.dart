import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../models/app_video.dart';
import '../services/simple_video_service.dart';

class HomeController extends GetxController {
  final linkController = TextEditingController();
  final service = SimpleVideoService();

  final isDark = true.obs;
  final isLoading = false.obs;
  final isDownloading = false.obs;
  final progress = 0.0.obs;
  final message = ''.obs;
  final savedPath = ''.obs;
  final selectedFormatId = ''.obs;
  final currentVideo = Rxn<AppVideo>();
  final recentItems = <AppVideo>[].obs;

  @override
  void onInit() {
    super.onInit();
    Get.changeThemeMode(ThemeMode.dark);
  }

  void changeTheme() {
    isDark.value = !isDark.value;
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> pasteLink() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      linkController.text = data.text!.trim();
    }
  }

  void fillDemo(String text) {
    linkController.text = text;
  }

  Future<void> getVideo() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = linkController.text.trim();

    if (text.isEmpty) {
      message.value = 'Pehle video link dalo.';
      return;
    }

    isLoading.value = true;
    message.value = '';
    savedPath.value = '';

    try {
      final video = await service.getVideoData(text);
      currentVideo.value = video;
      selectedFormatId.value = video.formats.isNotEmpty
          ? video.formats.first.id
          : video.qualityText;
      recentItems.removeWhere((item) => item.sourceUrl == video.sourceUrl);
      recentItems.insert(0, video);

      if (recentItems.length > 4) {
        recentItems.removeLast();
      }

      message.value = '${video.platform} video ready hai.';
    } catch (e) {
      currentVideo.value = null;
      message.value = _readError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> downloadVideo() async {
    final video = currentVideo.value;

    if (video == null) {
      message.value = 'Pehle video fetch karo.';
      return;
    }

    isDownloading.value = true;
    progress.value = 0;
    savedPath.value = '';
    message.value = '';

    try {
      final path = await service.downloadVideo(video, selectedFormat, (
        now,
        total,
      ) {
        if (total > 0) {
          progress.value = now / total;
        }
      });

      savedPath.value = path;
      message.value = 'Video download ho gayi.';
    } catch (e) {
      message.value = _readError(e);
    } finally {
      isDownloading.value = false;
    }
  }

  void openRecent(AppVideo video) {
    currentVideo.value = video;
    selectedFormatId.value = video.formats.isNotEmpty
        ? video.formats.first.id
        : video.qualityText;
    linkController.text = video.sourceUrl;
    savedPath.value = '';
    message.value = '${video.platform} result open ho gaya.';
  }

  void changeFormat(String? value) {
    if (value == null || value.isEmpty) {
      return;
    }

    selectedFormatId.value = value;
  }

  AppVideoFormat? get selectedFormat {
    final video = currentVideo.value;
    if (video == null) {
      return null;
    }

    for (final item in video.formats) {
      if (item.id == selectedFormatId.value) {
        return item;
      }
    }

    if (video.formats.isNotEmpty) {
      return video.formats.first;
    }

    return null;
  }

  @override
  void onClose() {
    linkController.dispose();
    super.onClose();
  }

  String _readError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;

      if (code == 403) {
        return 'Server ne access block kar diya (403). Public link ya fresh link try karo.';
      }

      if (code == 404) {
        return 'Video ya media link nahin mili (404).';
      }

      return 'Network request fail hui. Dusra link try karo.';
    }

    final text = error.toString().replaceFirst('Exception: ', '').trim();

    if (text.contains('403')) {
      return 'Server ne access block kar diya (403). Public link ya fresh link try karo.';
    }

    if (text.contains('Null check operator used on a null value')) {
      return 'Is link ka media parse nahin ho saka. Public post/reel link try karo.';
    }

    return text;
  }
}
