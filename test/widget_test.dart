import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_dd/main.dart';

void main() {
  testWidgets('app loads base downloader screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('All In One Video Downloader'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
