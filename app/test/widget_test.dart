import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retiros_app/main.dart';

void main() {
  testWidgets('La app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const RetirosApp());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
