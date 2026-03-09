import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dark = controller.isDark.value;
      final colors = Theme.of(context).colorScheme;

      return Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF070B14),
                      Color(0xFF11192B),
                      Color(0xFF18243B),
                    ]
                  : const [
                      Color(0xFFF8FBFF),
                      Color(0xFFEAF2FF),
                      Color(0xFFFFFFFF),
                    ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(colors, dark),
                  const SizedBox(height: 22),
                  _heroCard(colors, dark),
                  const SizedBox(height: 20),
                  _inputCard(colors, dark),
                  const SizedBox(height: 18),
                  _platformRow(colors, dark),
                  const SizedBox(height: 18),
                  _resultCard(colors, dark),
                  const SizedBox(height: 18),
                  _recentCard(colors, dark),
                  const SizedBox(height: 18),
                  _messageCard(colors, dark),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _topBar(ColorScheme colors, bool dark) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF4ADEDE), Color(0xFF3B82F6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video Downloader',
                style: Theme.of(Get.context!).textTheme.headlineSmall,
              ),
              Text(
                'Simple code, premium screen',
                style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.7)
                      : colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: controller.changeTheme,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : colors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: dark ? Colors.white : colors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(ColorScheme colors, bool dark) {
    return _glassCard(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Instagram, TikTok, Facebook, YouTube, X',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Ek link dalo aur stylish preview ke saath download karo.',
            style: Theme.of(Get.context!).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'App intentionally seedhi rakhi gayi hai. GetX state, clean cards, aur platform packages direct use ho rahe hain.',
            style: Theme.of(Get.context!).textTheme.bodyLarge?.copyWith(
              color: dark
                  ? Colors.white.withValues(alpha: 0.72)
                  : colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard(ColorScheme colors, bool dark) {
    return _glassCard(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste video link',
            style: Theme.of(Get.context!).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.linkController,
            minLines: 2,
            maxLines: 3,
            style: TextStyle(
              color: dark ? Colors.white : colors.onSurface,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'https://www.instagram.com/reel/... ya YouTube link',
              hintStyle: TextStyle(
                color: dark
                    ? Colors.white.withValues(alpha: 0.35)
                    : colors.onSurface.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : colors.primary.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.pasteLink,
                  icon: const Icon(Icons.content_paste_go_rounded),
                  label: const Text('Paste'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.getVideo,
                  icon: controller.isLoading.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    controller.isLoading.value ? 'Checking' : 'Get Video',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _demoChip(
                'Instagram demo',
                'https://www.instagram.com/reel/sample',
              ),
              _demoChip(
                'TikTok demo',
                'https://www.tiktok.com/@user/video/123',
              ),
              _demoChip(
                'YouTube demo',
                'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _platformRow(ColorScheme colors, bool dark) {
    final items = ['Insta', 'TikTok', 'Facebook', 'YouTube', 'X'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : colors.primary.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : colors.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _resultCard(ColorScheme colors, bool dark) {
    return Obx(() {
      final video = controller.currentVideo.value;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: video == null
            ? _glassCard(
                dark: dark,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        Icons.video_collection_rounded,
                        size: 44,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.85)
                            : colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Preview yahan show hoga',
                        style: Theme.of(Get.context!).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Link check karne ke baad thumbnail, title aur download button show hoga.',
                        textAlign: TextAlign.center,
                        style: Theme.of(Get.context!).textTheme.bodyMedium
                            ?.copyWith(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : colors.onSurface.withValues(alpha: 0.65),
                            ),
                      ),
                    ],
                  ),
                ),
              )
            : _glassCard(
                dark: dark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: video.thumbnail.isEmpty
                            ? Container(
                                color: dark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : colors.primary.withValues(alpha: 0.08),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 72,
                                  color: dark ? Colors.white : colors.primary,
                                ),
                              )
                            : Image.network(
                                video.thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: dark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : colors.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 54,
                                      color: dark
                                          ? Colors.white70
                                          : colors.primary,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoPill(video.platform, const Color(0xFF3B82F6)),
                        _infoPill(
                          controller.selectedFormat?.title ?? video.qualityText,
                          const Color(0xFF22C55E),
                        ),
                        _infoPill(video.author, const Color(0xFFF97316)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      video.title,
                      style: Theme.of(Get.context!).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      video.note,
                      style: Theme.of(Get.context!).textTheme.bodyMedium
                          ?.copyWith(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.7)
                                : colors.onSurface.withValues(alpha: 0.68),
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (video.formats.isNotEmpty) ...[
                      Text(
                        'Choose Resolution',
                        style: Theme.of(Get.context!).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: controller.selectedFormatId.value.isEmpty
                            ? video.formats.first.id
                            : controller.selectedFormatId.value,
                        items: video.formats.map((item) {
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.title),
                          );
                        }).toList(),
                        onChanged: controller.changeFormat,
                        dropdownColor: dark
                            ? const Color(0xFF18243B)
                            : Colors.white,
                        iconEnabledColor: dark ? Colors.white : colors.primary,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : colors.primary.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    controller.isDownloading.value
                        ? Column(
                            children: [
                              LinearProgressIndicator(
                                value: controller.progress.value == 0
                                    ? null
                                    : controller.progress.value,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${(controller.progress.value * 100).toStringAsFixed(0)}% downloading',
                                style: Theme.of(
                                  Get.context!,
                                ).textTheme.bodyMedium,
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: controller.downloadVideo,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download Now'),
                            ),
                          ),
                  ],
                ),
              ),
      );
    });
  }

  Widget _recentCard(ColorScheme colors, bool dark) {
    return Obx(() {
      if (controller.recentItems.isEmpty) {
        return const SizedBox.shrink();
      }

      return _glassCard(
        dark: dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent previews',
              style: Theme.of(Get.context!).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...controller.recentItems.map(
              (video) => InkWell(
                onTap: () => controller.openRecent(video),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : colors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF3B82F6,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.movie_creation_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${video.platform} • ${video.qualityText}',
                              style: TextStyle(
                                color: dark
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : colors.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _messageCard(ColorScheme colors, bool dark) {
    return Obx(() {
      final hasMessage = controller.message.value.isNotEmpty;
      final hasPath = controller.savedPath.value.isNotEmpty;

      if (!hasMessage && !hasPath) {
        return const SizedBox.shrink();
      }

      return _glassCard(
        dark: dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasMessage)
              Text(
                controller.message.value,
                style: Theme.of(Get.context!).textTheme.bodyLarge,
              ),
            if (hasPath) ...[
              const SizedBox(height: 10),
              Text(
                'Saved at:\n${controller.savedPath.value}',
                style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.72)
                      : colors.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Note: X videos ke liye `twitter_keys.dart` me bearer token chahiye.',
              style: Theme.of(Get.context!).textTheme.bodySmall?.copyWith(
                color: dark
                    ? Colors.white.withValues(alpha: 0.55)
                    : colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _demoChip(String text, String link) {
    return InkWell(
      onTap: () => controller.fillDemo(link),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF3B82F6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _infoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _glassCard({required Widget child, required bool dark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.white.withValues(alpha: 0.95),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.18 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
