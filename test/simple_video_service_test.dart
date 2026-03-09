import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/app/services/simple_video_service.dart';

void main() {
  final service = SimpleVideoService();

  test('normalizes youtube shorts url', () {
    final normalized = service.normalizeUrlForTest(
      'https://youtube.com/shorts/CkrckTOr47o?si=Juke3LRURaZhOpAp',
    );

    expect(normalized, 'https://www.youtube.com/watch?v=CkrckTOr47o');
  });

  test('normalizes youtu.be url', () {
    final normalized = service.normalizeUrlForTest(
      'https://youtu.be/dQw4w9WgXcQ?si=abc123',
    );

    expect(normalized, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  });

  test('normalizes facebook mobile watch url', () {
    final normalized = service.normalizeUrlForTest(
      'https://m.facebook.com/watch/?v=123456789&mibextid=abcd',
    );

    expect(normalized, 'https://www.facebook.com/watch?v=123456789');
  });

  test('normalizes fb.watch link', () {
    final normalized = service.normalizeUrlForTest(
      'https://fb.watch/abcDEF12/?mibextid=abcd',
    );

    expect(normalized, 'https://fb.watch/abcDEF12');
  });

  test('normalizes tiktok tracking params', () {
    final normalized = service.normalizeUrlForTest(
      'https://www.tiktok.com/@demo/video/1234567890?_t=abc&is_copy_url=1',
    );

    expect(normalized, 'https://www.tiktok.com/@demo/video/1234567890');
  });

  test('strips fragment from facebook url', () {
    final normalized = service.normalizeUrlForTest(
      'https://www.facebook.com/watch/?v=123#section',
    );

    expect(normalized, 'https://www.facebook.com/watch?v=123');
  });

  test('does not treat query text as platform host', () {
    final normalized = service.normalizeUrlForTest(
      'https://evil.com/?next=https://instagram.com/reel/demo',
    );

    expect(
      normalized,
      'https://evil.com/?next=https://instagram.com/reel/demo',
    );
  });
}
