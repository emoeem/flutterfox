// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../all_songs/all_songs_page.dart';
import '../../widgets/single_line_lyrics.dart';
import '../setting/settings_provider.dart';
import '../../widgets/custom_background_layer.dart';

class AllSongs extends StatelessWidget {
  const AllSongs({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: CustomBackgroundSurfaces.transparentWhenEnabled(
        settings,
        colorScheme.surface,
      ),
      appBar: AppBar(
        title: const SingleLineLyricView(
          maxLinesPerLyric: 2,
          textAlign: TextAlign.left,
          alignment: Alignment.topLeft,
        ),
        backgroundColor: CustomBackgroundSurfaces.transparentWhenEnabled(
          settings,
          colorScheme.surface,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: const Column(
        children: [
          Divider(height: 1, thickness: 1),
          Expanded(child: AllSongsPage()),
        ],
      ),
    );
  }
}
