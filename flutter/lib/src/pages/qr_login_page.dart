/// 扫码登录页：二维码大卡 + 状态文本（登录态由 Rust 音源侧写入会话存储）。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;

class QrLoginPage extends StatelessWidget {
  final AppModel model;

  const QrLoginPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final session = model.qrSession;
    final status = model.qrStatus;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (session == null) ...[
          const SizedBox(height: 48),
          Center(
            child: Wrap(
              spacing: 12,
              children: [
                for (final entry in const {
                  'kg': '酷狗',
                  'tx': 'QQ 音乐',
                  'wy': '网易云',
                  'bili': '哔哩哔哩',
                }.entries)
                  FilledButton.tonal(
                    onPressed: () => model.dispatch(
                        bridge.FfiCommand.qrLoginStart(
                            source: entry.key, kind: 'standard')),
                    child: Text(entry.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              status == null ? '选择音源生成登录二维码' : '登录状态：$status',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (status != null && status != 'success')
            Center(
              child: TextButton(
                onPressed: () =>
                    model.dispatch(const bridge.FfiCommand.qrLoginCancel()),
                child: const Text('取消登录'),
              ),
            ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '${session.source} · ${session.kind == 'wechat' ? '微信扫码' : 'App 扫码'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: _QrView(session: session),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusText(status),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (model.qrUser != null)
                    Text(
                      '已登录：${model.qrUser}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        model.dispatch(const bridge.FfiCommand.qrLoginCancel()),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _statusText(String? status) {
    switch (status) {
      case 'waiting':
        return '等待扫码…';
      case 'scanned':
        return '已扫码，请在手机上确认';
      case 'success':
        return '登录成功';
      case 'expired':
        return '二维码已过期，请重新生成';
      default:
        return '状态：${status ?? '未知'}';
    }
  }
}

class _QrView extends StatelessWidget {
  final bridge.QrLoginSessionDto session;

  const _QrView({required this.session});

  @override
  Widget build(BuildContext context) {
    final image = session.imagePngBase64;
    if (image != null && image.isNotEmpty) {
      // 部分平台返回图片字节（base64），直接渲染
      final raw = image.contains(',')
          ? image.split(',')[1]
          : image;
      try {
        return Image.memory(
          base64Decode(raw),
          fit: BoxFit.contain,
        );
      } on FormatException {
        // fallthrough 到 URL 渲染
      }
    }
    if (session.url.isEmpty) {
      return const Center(child: Text('该渠道未返回二维码内容'));
    }
    // 渠道只回了 URL（无 PNG 字节）：本地用 qr_flutter 渲染成二维码。
    return Center(
      child: QrImageView(
        data: session.url,
        size: 220,
        backgroundColor: Colors.white,
      ),
    );
  }
}
