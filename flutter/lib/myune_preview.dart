// Dev preview entry for the vendored myune player page.
// Run: flutter run -d linux -t lib/myune_preview.dart
// Not shipped in the app (main.dart is the real entry); kept so the new shell
// can be inspected without a playing track.
import 'package:flutter/material.dart';

import 'src/app_model.dart';
import 'src/myune_shell/myune_player_page.dart';
import 'src/theme/voicefox_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildVoicefoxTheme('flclash', Brightness.dark),
      home: MyunePlayerPage(model: model),
    ),
  );
}
