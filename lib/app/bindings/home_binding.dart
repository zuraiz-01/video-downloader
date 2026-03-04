import 'package:get/get.dart';

import '../controllers/download_controller.dart';
import '../services/downloader/downloader_service.dart';
import '../services/extractors/extractors.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get
      ..lazyPut(UrlClassifier.new)
      ..lazyPut(() => ExtractorRegistry(Get.find()))
      ..lazyPut(DownloaderService.new)
      ..put(DownloadController(Get.find(), Get.find()));
  }
}
