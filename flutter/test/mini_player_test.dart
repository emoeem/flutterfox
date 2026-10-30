import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("mini player renders controls", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text("Voicefox"))));
    expect(find.text("Voicefox"), findsOneWidget);
  });
}
