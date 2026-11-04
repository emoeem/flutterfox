// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
// https://github.com/amll-dev/amll-ttml-db

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../parser/parsed_models.dart';
import '../parser/yrc_parser.dart';

class AmllFetcher {
  static const _baseUrl =
      'https://raw.githubusercontent.com/amll-dev/amll-ttml-db/refs/heads/main';

  // 平台对应的 AMLL 文件夹
  static const _platformDirs = {
    'netease': 'ncm-lyrics',
    'qqmusic': 'qq-lyrics',
  };

  // 默认下载格式
  static const _defaultFormat = 'yrc';

  final _yrcParser = YrcParser();

  // 通过歌曲 ID 从 AMLL 数据库获取歌词
  Future<ParsedLyrics?> fetchById(
    String platform,
    String songId, {
    String format = _defaultFormat,
  }) async {
    final dirName = _platformDirs[platform];
    if (dirName == null) return null;

    final url = '$_baseUrl/$dirName/$songId.$format';

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      final content = utf8.decode(response.bodyBytes);
      if (content.isEmpty) return null;

      // 使用 YRC 解析器解析（因为下载的是 .yrc 格式）
      return _yrcParser.parse(content);
    } catch (_) {
      return null;
    }
  }
}
