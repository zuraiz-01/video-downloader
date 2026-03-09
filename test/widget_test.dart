import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_downloader/main.dart';

void main() {
  testWidgets('video downloader home screen loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Video Downloader'), findsOneWidget);
    expect(find.text('Paste video link'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });
}
