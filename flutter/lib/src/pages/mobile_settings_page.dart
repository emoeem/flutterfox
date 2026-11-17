/// 手机设置页（计划书 C-06，指南 §6.3「手机设置使用分组列表与独立二级
/// 设置页；避免直接把桌面双栏设置挤进手机宽度」；Batch C-D）。
///
/// 结构（MobileShell body 槽 + 抽屉二级入口共用）：
/// - [MobileSettingsPage]：壳 body 分组列表（9 组入口，icon + label +
///   chevron，触控目标 ≥48dp），点组推入 [MobileSettingsSectionPage]；
///   [initialSection] 种子（抽屉「音源管理」→ sources 分组）在首帧后自动
///   推入对应二级页（只推一次）；
/// - [MobileSettingsSectionPage]：推入路由自带 Scaffold + AppBar（返回/
///   分组名），内容与桌面双栏右侧同一实现（[SettingsSectionContent]，
///   业务与布局单一出处）。
///
/// 无自带 Scaffold（列表页是壳 body——inset 契约见 shell/android_insets.dart；
/// 二级页是推入路由，自带 Scaffold 承担系统 inset）。
/// 设置项全部即时下发 updateConfig（无未保存态）；保存失败由命令层全局
/// toast 呈现，配置真源以 Rust 回流快照为准（失败不伪造成功）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import '../shell/android_insets.dart' show mobileListBottomPadding;
import 'settings_page.dart';

class MobileSettingsPage extends StatefulWidget {
  final AppModel model;

  /// 抽屉「音源管理」等入口的分组种子；null 从分组列表开始。
  final SettingsSection? initialSection;

  const MobileSettingsPage(this.model, {super.key, this.initialSection});

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  /// 种子分组只自动推入一次（用户从二级页返回后停留在分组列表）。
  bool _seedPushed = false;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _seedPushed) return;
        _seedPushed = true;
        _openSection(context, widget.initialSection!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            '设置',
            style: VxTypography.h2.copyWith(color: scheme.onSurface),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, mobileListBottomPadding()),
            children: [
              for (final section in SettingsSection.values)
                _groupRow(context, section),
            ],
          ),
        ),
      ],
    );
  }

  /// 分组入口行：icon + label + chevron；触控目标 ≥48dp（§5.9）。
  Widget _groupRow(BuildContext context, SettingsSection section) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(VxRadius.md),
        onTap: () => _openSection(context, section),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(VxRadius.md),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.label,
                  style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
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
    );
  }

  void _openSection(BuildContext context, SettingsSection section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileSettingsSectionPage(
          _model,
          section,
          key: ValueKey('mobile-settings-${section.name}'),
        ),
      ),
    );
  }
}

/// 手机设置二级页：单个分组的设置项内容（与桌面双栏右侧同一实现）。
///
/// 推入路由自带 Scaffold + AppBar；config 未达时如实显示加载态
/// （与桌面页「配置加载中…」同口径，不伪造设置项）。
class MobileSettingsSectionPage extends StatelessWidget {
  final AppModel model;
  final SettingsSection section;

  const MobileSettingsSectionPage(this.model, this.section, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.label)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) {
            if (model.config == null) {
              // IndexedStack 常驻语境之外的推入页可安全用指示器；
              // 与桌面口径一致不改文案（§9 加载态）。
              return const Center(child: Text('配置加载中…'));
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                mobileListBottomPadding(),
              ),
              children: [
                SettingsSectionContent(model: model, section: section),
              ],
            );
          },
        ),
      ),
    );
  }
}
