import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/home_binding.dart';
import 'app/theme/app_theme.dart';
import 'app/views/home_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Video Downloader',
      debugShowCheckedModeBanner: false,
      initialBinding: HomeBinding(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeView(),
    );
  }
}
