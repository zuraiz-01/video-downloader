import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/download_controller.dart';
import '../models/video_models.dart';

class HomeView extends GetView<DownloadController> {
  const HomeView({super.key});

  static const _spinner = SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('All In One Video Downloader')),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F2E6), Color(0xFFEFE4CE), Color(0xFFE4D7BC)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -50,
            child: _glow(280, const Color(0x33B8903D)),
          ),
          Positioned(
            bottom: -130,
            left: -80,
            child: _glow(320, const Color(0x22143A52)),
          ),
          SafeArea(
            child: Obx(() {
              final c = controller;
              final info = c.videoInfo.value;
              final busy = c.isAnalyzing.value || c.isDownloading.value;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _reveal(0, _hero(context)),
                      const SizedBox(height: 14),
                      _reveal(1, _inputPanel(context, c, busy)),
                      const SizedBox(height: 14),
                      _reveal(2, _notice()),
                      _message(
                        order: 3,
                        text: c.errorMessage.value,
                        bg: const Color(0xFFFBE8E8),
                        border: const Color(0xFFE9B3B3),
                        fg: const Color(0xFF8C1E1E),
                        icon: Icons.error_outline_rounded,
                      ),
                      _message(
                        order: 4,
                        text: c.statusMessage.value,
                        bg: const Color(0xFFE7F6EE),
                        border: const Color(0xFFB3DEC3),
                        fg: const Color(0xFF0E6A39),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      if (info != null) ...[
                        const SizedBox(height: 14),
                        _reveal(5, _videoPanel(context, c, info)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );

  Widget _hero(BuildContext context) => _panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFF143A52),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download Lounge',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF112E42),
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paste YouTube or direct media link. Pick the quality you want and download with live progress.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF324A59)),
              ),
            ],
          ),
        ),
      ],
    ),
    gradient: const LinearGradient(
      colors: [Color(0xEBFFFFFF), Color(0xD8FFF8EA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  Widget _inputPanel(BuildContext context, DownloadController c, bool busy) =>
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Video URL',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF17364A)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: c.linkController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Video / Reel URL',
                hintText: 'https://...',
              ),
              onSubmitted: (_) => c.analyze(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : c.analyze,
              icon: c.isAnalyzing.value
                  ? _spinner
                  : const Icon(Icons.search_rounded),
              label: Text(c.isAnalyzing.value ? 'Analyzing...' : 'Analyze'),
            ),
          ],
        ),
      );

  Widget _notice() => _panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF8D6B2A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Public links usually work. Private posts or heavily protected streams can fail without API/auth access.',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
    gradient: const LinearGradient(
      colors: [Color(0xF9FFF6DF), Color(0xF5FFF1CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  Widget _message({
    required int order,
    required String? text,
    required Color bg,
    required Color border,
    required Color fg,
    required IconData icon,
  }) {
    final value = text ?? '';
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _reveal(
        order,
        _panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          color: bg,
          borderColor: border,
        ),
      ),
    );
  }

  Widget _videoPanel(
    BuildContext context,
    DownloadController c,
    VideoInfo info,
  ) {
    final isDownloading = c.isDownloading.value;
    final disabled = isDownloading || c.selectedFormat == null;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: const Color(0xFF132F42)),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(info.platform.label),
            avatar: const Icon(Icons.language_rounded, size: 16),
          ),
          const SizedBox(height: 10),
          _thumbnail(info.thumbnailUrl),
          const SizedBox(height: 14),
          Text(
            'Available Qualities',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF17364A)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4C39F)),
              color: Colors.white.withValues(alpha: 0.74),
            ),
            child: Column(
              children: [for (final f in info.formats) _formatTile(c, f)],
            ),
          ),
          const SizedBox(height: 14),
          if (isDownloading)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: c.progress.value,
                minHeight: 9,
                color: const Color(0xFF143A52),
                backgroundColor: const Color(0xFFDCC9A3),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: disabled ? null : c.downloadSelected,
            icon: isDownloading ? _spinner : const Icon(Icons.download_rounded),
            label: Text(isDownloading ? 'Downloading...' : 'Download'),
          ),
        ],
      ),
      gradient: const LinearGradient(
        colors: [Color(0xEAFFFFFF), Color(0xDDFCF6E8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _thumbnail(String? url) {
    if (url == null || url.isEmpty) {
      return _thumbBox(const Icon(Icons.ondemand_video_rounded, size: 40));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) =>
              _thumbBox(const Icon(Icons.broken_image_rounded, size: 40)),
        ),
      ),
    );
  }

  Widget _thumbBox(Widget child) => Container(
    height: 180,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD4C39F)),
      color: Colors.white.withValues(alpha: 0.7),
    ),
    child: child,
  );

  Widget _formatTile(DownloadController c, VideoFormat format) {
    final selected = c.selectedFormatId.value == format.id;
    final subtitle = format.hasAudio
        ? 'Container: ${format.container.toUpperCase()}'
        : 'Video only (${format.container.toUpperCase()})';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF143A52) : const Color(0x00000000),
          width: 1.2,
        ),
        color: selected
            ? const Color(0x21143A52)
            : Colors.white.withValues(alpha: 0.6),
      ),
      child: ListTile(
        enabled: !c.isDownloading.value,
        onTap: c.isDownloading.value ? null : () => c.pickFormat(format.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        title: Text(format.label),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected
              ? Icons.verified_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? const Color(0xFF143A52) : const Color(0xFF997B41),
        ),
      ),
    );
  }

  Widget _panel({
    required Widget child,
    Color? color,
    Color borderColor = const Color(0xFFD8C8A6),
    Gradient? gradient,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? const Color(0xEFFFFFFF),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: borderColor, width: 1.1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
      gradient: gradient,
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _reveal(int order, Widget child) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: 380 + (order * 90)),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, value, item) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 18),
        child: item,
      ),
    ),
    child: child,
  );

  static Widget _glow(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          radius: 0.82,
        ),
      ),
    ),
  );
}
