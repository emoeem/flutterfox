/// 设置页手机形态（Batch C-C→C-D C-06 / R6，SR-03 手机 8 页复用桌面收敛）。
///
/// 布局（handoff C-D「桌面 208 双栏不照搬」）：分组卡片列表为入口，
/// 点分组推入全屏二级页。二级页复用桌面 `SettingsPage(initialSection:)` 的
/// **窄宽形态**（<640 宽自动切 ChoiceChip 单列导航，双栏导航不会出现在
/// 手机宽度）——设置行原语 / 保存失败展示 / 离开页面不静默丢失（全部
/// commit-on-submit / commit-on-drag-end 语义）直接继承桌面实现，业务零复制。
///
/// `initialSection` 非 null 时（抽屉「音源管理」种子，mobile_shell
/// KeyedSubtree 重建机制）直接定位到该分组的二级页（帧后推入，避免
/// push during build）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import 'settings_page.dart' show SettingsPage, SettingsSection;

/// 设置页（手机）：分组入口 + 全屏二级页。
class MobileSettingsPage extends StatefulWidget {
  const MobileSettingsPage({
    super.key,
    required this.model,
    this.initialSection,
  });

  final AppModel model;

  /// 抽屉种子分组；非 null 时进入页面即定位该分组二级页（一次性）。
  final SettingsSection? initialSection;

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  bool _seedHandled = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_seedHandled) {
          _seedHandled = true;
          _openSection(widget.initialSection!);
        }
      });
    }
  }

  void _openSection(SettingsSection section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(section.label)),
          body: SettingsPage(widget.model, initialSection: section),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final section in SettingsSection.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(VxRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VxRadius.lg),
                    onTap: () => _openSection(section),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            section.icon,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              section.label,
                              style: VxTypography.title.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
