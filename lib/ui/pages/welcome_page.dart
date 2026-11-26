// OOBE 向导：按原包 FirstSetupWizard 逆向还原
// （layout_setupwizard_firstendtable / layout_protocol_confirm /
//   layout_backup_and_cloneappdata / layout_service_permission_description）。
// 第一页背景为 dynamicBackgroundView 的轮换径向渐变（紫 #632EFF / 蓝 #007AFF /
// 粉 #FF8BC5 / 橙 #FFA88B，底色 #F2F1F6，ValueAnimator 无限往复）。
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/system_bridge.dart';
import '../widgets/confirm.dart';
import '../app_messenger.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('org.roam.roam_flutter/photo_picker');

  final _pages = PageController();
  int _step = 0;
  bool _autoBackup = true;

  // dynamicBackgroundView：色块位置无限往复轮换
  late final AnimationController _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bg.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step < 4) {
      _goTo(_step + 1);
    } else {
      widget.onDone();
    }
  }

  void _prev() {
    if (_step > 0) _goTo(_step - 1);
  }

  Future<void> _openUrl(String url) async {
    await SystemBridge.openExternal(url);
  }

  /// 打开系统文件选择器（安装备份 / 导入书签）
  Future<void> _pickFile(String label) async {
    try {
      final path = await _channel.invokeMethod<String>('pickFile');
      if (!mounted) return;
      if (path != null) {
        showRoamToast('已选择「$label」文件');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      showRoamToast('选择文件失败：${e.message}');
    }
  }

  /// 删除自动备份内容
  Future<void> _deleteBackup() async {
    final confirmed = await showRoamConfirm(
      context: context,
      title: '删除自动备份',
      message: '确定要删除所有自动备份的数据吗？此操作不可撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    showRoamToast('已删除自动备份内容');
  }

  /// 打开系统应用详情页
  Future<void> _openAppDetails() async {
    try {
      await _channel.invokeMethod<bool>('openAppDetails');
    } on PlatformException catch (e) {
      if (!mounted) return;
      showRoamToast('无法打开应用详情：${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 轮换渐变背景（第一页透出）
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bg,
              builder: (context, _) =>
                  CustomPaint(painter: _GradientBlobsPainter(_bg.value)),
            ),
          ),
          PageView(
            controller: _pages,
            onPageChanged: (value) => setState(() => _step = value),
            children: [
              _buildWelcome(),
              _buildProtocol(),
              _buildBackup(),
              _buildPermission(),
              _buildFinish(),
            ],
          ),
        ],
      ),
    );
  }

  // ---- 第一页：欢迎（渐变背景） ----
  Widget _buildWelcome() {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          // logo 236×36.86dp 白色着色（firstendtable）
          Image.asset(
            'assets/images/roam_explore_logo.png',
            width: 236,
            height: 36.86,
            fit: BoxFit.fill,
            color: Colors.white,
          ),
          const SizedBox(height: 10),
          const Text(
            '欢迎使用',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // welcomeButton 70dp 圆、白 19% 底、白描边，按下缩放 0.9
          Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: _CircleArrowButton(onTap: _next),
          ),
        ],
      ),
    );
  }

  // ---- 第二页：协议与声明 ----
  Widget _buildProtocol() {
    return _StepShell(
      title: '协议与声明',
      subtitle: '阅读并同意以下协议、政策及声明',
      buttons: _StepButtons(
        leftLabel: '不同意',
        rightLabel: '同意并继续',
        onLeft: () => _showDisagreeDialog(),
        onRight: _next,
      ),
      children: [
        const _GroupLabel('法律协议与政策'),
        _LinkCard(
          icon: Icons.description_outlined,
          label: '星环软件使用协议',
          onTap: () =>
              _openUrl('https://roamexplore.rth1.xyz/USERAGREEMENT_CN.html'),
        ),
        _LinkCard(
          icon: Icons.lock_outline,
          label: '星环软件隐私政策',
          onTap: () =>
              _openUrl('https://roamexplore.rth1.xyz/PRIVACYPOLICY_CN.html'),
        ),
        const _GroupLabel('三方协议'),
        _LinkCard(
          icon: Icons.list_alt_outlined,
          label: '三方信息共享清单',
          onTap: () =>
              _openUrl('https://roamexplore.rth1.xyz/PRIVACYPOLICY_CN.html'),
        ),
        const _GroupLabel('开放源代码'),
        _LinkCard(
          icon: Icons.code_outlined,
          label: 'ROPS 2026',
          onTap: () => _openUrl('https://gitee.com/hairouse/roam_explore'),
        ),
        const _GroupLabel('字体版权'),
        _InfoCard(
          child: Text(
            '<TCloudNumber-Regular>\n'
            'Copyright (c) 2021~present TDesign.\n'
            'All rights are reserved under the SIL Open Font License, Version 1.1',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              fontFamily: 'monospace',
              color: const Color(0xFF0B1526).withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }

  void _showDisagreeDialog() {
    showRoamDialog<bool>(
      context: context,
      title: '需要同意协议',
      message: '你需要同意协议与声明后才能继续使用星环软件。',
      actions: const [
        RoamDialogAction(label: '再想想', value: false),
        RoamDialogAction(label: '返回阅读', value: true, primary: true),
      ],
    );
  }

  // ---- 第三页：备份与恢复 ----
  Widget _buildBackup() {
    return _StepShell(
      title: '备份与恢复',
      subtitle: '恢复数据，并继续使用星环软件',
      buttons: _StepButtons(
        leftLabel: '上一步',
        rightLabel: '继续',
        onLeft: _prev,
        onRight: _next,
      ),
      children: [
        const _GroupLabel('管理备份文件'),
        _LinkCard(
          icon: Icons.inventory_2_outlined,
          label: '安装备份',
          onTap: () => _pickFile('安装备份'),
        ),
        _InfoCard(
          child: Row(
            children: [
              const Icon(
                Icons.backup_outlined,
                size: 20,
                color: Color(0xFF0B1526),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('每3天自动备份数据')),
              Switch(
                value: _autoBackup,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF3482FF),
                onChanged: (value) => setState(() => _autoBackup = value),
              ),
            ],
          ),
        ),
        _LinkCard(
          icon: Icons.delete_outline,
          label: '删除自动备份的内容',
          onTap: _deleteBackup,
        ),
        const _GroupLabel('独立备份项'),
        _LinkCard(
          icon: Icons.move_to_inbox_outlined,
          label: '从其他 App 导入书签',
          onTap: () => _pickFile('书签'),
        ),
      ],
    );
  }

  // ---- 第四页：服务权限说明 ----
  Widget _buildPermission() {
    const items = [
      (Icons.apps, '已安装的应用列表权限', '该权限用于当网页需要调用对应App进行操作时正确识别并拉起对应的程序。'),
      (
        Icons.wifi,
        'WiFi、移动数据与有线网络',
        '该权限含无线局域网与蜂窝网络等通信网络，该权限用于App访问互联网以保证服务的正确使用。',
      ),
      (
        Icons.notifications_none,
        '通知与实时活动服务',
        '该权限用于保证软件更新、常驻后台通知与正在进行的实时活动服务的消息内容的及时推送。',
      ),
      (
        Icons.folder_open_outlined,
        '图片、视频和音频及其他文件',
        '该权限用于保存你在网络中获取的文件内容和App部分功能的正常使用。',
      ),
      (
        Icons.content_paste_outlined,
        '剪贴板',
        '该权限用于你在App内浏览网页或搜索内容时快捷粘贴或复制网络中的文本内容。',
      ),
      (Icons.camera_alt_outlined, '相机', '该权限用于二维码扫描和使用相机功能时预览与拍摄图片。'),
      (
        Icons.location_on_outlined,
        '地理位置信息',
        '某些网站需要您提供具体或大致的地理位置信息才能使用，例如天气或地图类网站。',
      ),
      (Icons.volume_up_outlined, '修改音频设置', '该权限用于在软件内播放音频内容时优化音频效果。'),
      (Icons.vibration, '振动', '软件需要此权限才能为你在操作部分功能时提供丰富的触感体验。'),
    ];
    return _StepShell(
      title: '服务权限说明',
      subtitle: '推荐开启以下权限，带来更好体验',
      buttons: _StepButtons(
        leftLabel: '上一步',
        rightLabel: '继续',
        onLeft: _prev,
        onRight: _next,
      ),
      children: [
        const _GroupLabel('系统权限管理'),
        _LinkCard(
          icon: Icons.settings_outlined,
          label: '应用详情页',
          onTap: _openAppDetails,
        ),
        const _GroupLabel('权限申请说明'),
        for (final (icon, title, desc) in items)
          _InfoCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: const Color(0xFF0B1526)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B1526),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: const Color(0xFF0B1526).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- 第五页：让我们开始吧 ----
  Widget _buildFinish() {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                children: [
                  TextSpan(
                    text: '让我们',
                    style: TextStyle(color: Color(0xFF1A1A1A)),
                  ),
                  TextSpan(
                    text: '开始吧',
                    style: TextStyle(color: Color(0xFFFF2E2E)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'roam explore',
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF0B1526).withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 35, right: 35),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: _PillButton(
                  label: '开启 ROAM AI Explore ✦',
                  dark: true,
                  onTap: widget.onDone,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 通用部件 ----

/// 中间页外壳：浅底 + 标题 + 滚动内容 + 底部按钮。
class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.buttons,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget buttons;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F1F6),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B1526),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF0B1526).withValues(alpha: 0.55),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                children: children,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: buttons,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButtons extends StatelessWidget {
  const _StepButtons({
    required this.leftLabel,
    required this.rightLabel,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: _PillButton(label: leftLabel, dark: false, onTap: onLeft),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 46,
            child: _PillButton(label: rightLabel, dark: true, onTap: onRight),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.label,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.dark
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFE8E8EA),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.dark ? Colors.white : const Color(0xFF0B1526),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleArrowButton extends StatefulWidget {
  const _CircleArrowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CircleArrowButton> createState() => _CircleArrowButtonState();
}

class _CircleArrowButtonState extends State<_CircleArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // welcomeButton：70dp 圆、白 19% 底、白 13% 描边，按下缩放 0.9（原 onTouch）
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.19),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 26,
            shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B1526),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _InfoCard(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0B1526)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0B1526),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: const Color(0xFF0B1526).withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ---- 轮换渐变背景（dynamicBackgroundView） ----

class _GradientBlobsPainter extends CustomPainter {
  _GradientBlobsPainter(this.t);

  /// 0~1，无限往复（REVERSE）。
  final double t;

  static const _base = Color(0xFFF2F1F6);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _base);

    // (颜色, 中心x, 中心y, 半径除数, 相位) —— 取自 main.lua 的四次调用
    final blobs = <(Color, double, double, double, double)>[
      (const Color(0xFF632EFF), 0.2, 0.2, 1.6, 0.0), // 紫
      (const Color(0xFF007AFF), 0.8, 0.3, 1.8, 0.25), // 蓝
      (const Color(0xFFFF8BC5), 0.3, 0.7, 1.7, 0.5), // 粉
      (const Color(0xFFFFA88B), 0.7, 0.6, 1.5, 0.75), // 橙
    ];

    for (final (color, cx, cy, rDiv, phase) in blobs) {
      // 无限往复轮换：位置沿相位轻微漂移
      final wobble = math.sin((t + phase) * math.pi * 2) * 0.05;
      final wobble2 = math.cos((t + phase) * math.pi * 2) * 0.05;
      final center = Offset(
        (cx + wobble) * size.width,
        (cy + wobble2) * size.height,
      );
      final radius = size.width / rDiv;
      final rect = Rect.fromCircle(center: center, radius: radius);
      // 圆形绘制 + 边缘完全透明，避免矩形接缝
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_GradientBlobsPainter oldDelegate) => oldDelegate.t != t;
}
