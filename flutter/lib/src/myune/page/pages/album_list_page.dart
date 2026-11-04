// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../song_list/album_list.dart';
import '../setting/settings_provider.dart';
import '../../widgets/custom_background_layer.dart';

class AlbumListPage extends StatelessWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: CustomBackgroundSurfaces.transparentWhenEnabled(
        settings,
        Theme.of(context).colorScheme.surface,
      ),
      body: const AlbumList(),
    );
  }
}
