# 星环 Roam（Flutter 重构版）

> 基于 Flutter 的移动端浏览器，复刻 HyperOS / MIUI 的视觉语言：毛玻璃材质、动态壁纸、可自定义主界面与完整的浏览器功能。
> 当前版本：**1.0.43+151** · Android 与 HarmonyOS NEXT 双端构建。

## 功能特性

- **浏览器内核**：多标签页、地址栏智能解析、书签 / 历史 / 下载管理、网页权限申请（相机、麦克风、定位、剪贴板）、URL Scheme 外部跳转
- **HyperOS 玻璃视觉**：基于 [`flutter_miuix`](https://pub.dev/packages/flutter_miuix) 1.4.0 的玻璃体系（材质、圆角、描边、遮罩），顶栏渐进模糊、弹层官方玻璃表面、边缘渐隐、壁纸与主题联动
- **深度自定义**：外观 / 字体 / 壁纸 / 应用图标、工具栏与底栏自定义、小组件（笔记、天气、相册、相机、日历）、模糊质量与自定义玻璃参数
- **隐私与安全**：应用锁（密码 / 生物验证）、网站行为管控、Cookie 与浏览数据清理、AI 翻译开关、无障碍设置
- **交互细节**：预测式返回、侧滑返回、滚动渐隐、启动引导、移动端手势与系统 UI 联动
- **双端支持**：Android（arm64-v8a / armeabi-v7a）与 HarmonyOS NEXT（未签名 HAP），共用同一套 Dart 代码

## 技术栈

| 类别 | 选型 |
|---|---|
| 框架 | Flutter `oh-3.50.0-preview`（鸿蒙分支）/ Dart ^3.14.0 |
| UI 组件 | `flutter_miuix` ^1.4.0（MIUI / HyperOS 风格组件与玻璃体系） |
| 内核 | `webview_flutter` ^4.14.1 + Android / HarmonyOS 联邦插件 |
| 状态与存储 | `BrowserController`（ChangeNotifier）+ `shared_preferences` |
| 平台通道 | 选图 / 打开文件 / URL Scheme / 剪贴板（Android `MainActivity.kt`、鸿蒙 `EntryAbility.ets`） |
| 图形 | 自绘片元着色器 `shaders/roam_glass.frag` + miuix 纹理模糊 / 渐进模糊 |

## 目录结构

```
roam_flutter/
├── lib/
│   ├── main.dart / app.dart           # 入口与全局主题、OOBE、生命周期
│   ├── models/browser_models.dart     # 标签、书签、历史、下载、设置等模型
│   ├── state/browser_controller.dart  # 全局状态与持久化
│   ├── services/                      # 下载、翻译、应用锁、URL 解析、权限、快照缓存
│   ├── theme/roam_theme.dart          # 明暗主题、字体与玻璃参数
│   └── ui/
│       ├── pages/                     # 主页、设置、下载、书签、历史、外观等 21 个页面
│       ├── widgets/                   # 顶栏、玻璃控件、弹层、侧滑返回、渐隐等组件
│       ├── glass/                     # 玻璃材质与模糊工具
│       └── browser_shell.dart         # 浏览器外壳（标签 / 多窗口）
├── android/                           # Android 工程与平台通道
├── ohos/                              # HarmonyOS NEXT 工程（ArkTS）
├── shaders/                           # 自绘玻璃着色器
├── assets/                            # 图标、壁纸、工具栏资源
├── tool/                              # CI 构建与鸿蒙 HAR 补丁脚本
├── test/                              # Widget 测试与视觉回归（golden）
├── .github/workflows/                 # GitHub Actions：Release 自动发布
├── .gitcode/workflows/                # GitCode Actions：APK / HAP 构建
├── CI.md                              # 自动构建说明
└── HARMONYOS.md                       # 鸿蒙适配说明与已知限制
```

## 本地开发

### 环境要求

- Flutter SDK：项目使用鸿蒙版 `oh-3.50.0-preview`（普通 Android 开发也可用官方 Flutter 3.50 / Dart 3.14）
- Android：JDK 17、Android SDK platform 36、build-tools 36.0.0、NDK 28.2.13676358
- HarmonyOS：DevEco commandline-tools 5.1.0.840（SDK API 18）；详见 [`HARMONYOS.md`](HARMONYOS.md)

```bash
flutter pub get
flutter analyze lib        # 静态分析
flutter test               # 全部测试（含 golden 视觉回归）
```

调试运行：

```bash
flutter run -d <device-id>
```

### 构建发布包

Android（双 ABI release APK）：

```bash
flutter build apk --release --split-per-abi
# 产物：build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#      build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

HarmonyOS NEXT（未签名 HAP）：

```bash
export HOS_SDK_HOME=/path/to/harmonyos/sdk
flutter build hap --release
# 产物：ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
# 签名与安装步骤见 HARMONYOS.md
```

> 本仓库的历史构建脚本约定：使用鸿蒙版 Flutter 构建 Android 时设置
> `HOS_SDK_HOME`，否则 `webview_flutter_ohos` 在 Android 侧会报
> `OhosViewController` 未定义。CI 中由 `tool/ci_build.sh` 统一处理。

## 玻璃效果实现约定

这部分是项目里最容易踩坑的地方，改动前请先看 `.claude/skills/flutter-miuix/references/80_blur.zh.md`。

- **弹层**：`RoamPopupGlass` 标准态直接调用 miuix 官方表面构建器 `miuixGlassBottomSheetSurface` / `miuixGlassDialogSurface`，不自己拼模糊与描边；材质、圆角、描边全部由库出。
- **顶栏渐隐**：`MiuixProgressiveTextureBlur` —— 单张满强度模糊图 + 连续 alpha 遮罩，不用「多档模糊叠加」（会产生重影、断层与卡顿）。
- **采样源**：`RoamBackdropScope` 维护页面级 backdrop 和「最近活跃页」回退，解决在二级页打开弹层却糊到主页壁纸的问题。
- **滑块**：`MiuixSlider` 在 `Column` 里需要 `SizedBox(width: double.infinity)` 撑满宽度，否则宽度坍缩为 0。

## 自动化构建

| 平台 | 工作流 | 触发 |
|---|---|---|
| GitCode | `.gitcode/workflows/build.yml` | push `main`、MR、`v*` 标签、手动 |
| GitHub | `.github/workflows/build-release.yml` | `v*` 标签、手动；构建后发布 Release |

两者共用 `tool/ci_build.sh`，产物为两个 release APK 和一个未签名 HAP。详细配置、缓存与排错见 [`CI.md`](CI.md)。

版本发布时只需修改 `pubspec.yaml` 的 `version: x.y.z+build`，然后打标签：

```bash
git tag v1.0.43
git push origin main --tags
```

## 已知限制

- HarmonyOS HAP 未签名，需要 DevEco Studio 自动签名或自备 `.p12/.cer/.p7b` 才能安装。
- 鸿蒙端目前只做到「编译通过」，玻璃着色器、平台视图、选图通道尚未在真机验证。
- 模糊采样基于快照（`MiuixLayerBackdropCapture`），快照分辨率固定 `pixelRatio: 1`；极快滚动时模糊画面比当前帧晚一帧，静止后对齐。

## 相关文档

- [`CI.md`](CI.md) —— 自动构建、Release 发布、工具链与排错
- [`HARMONYOS.md`](HARMONYOS.md) —— 鸿蒙工程改造、平台通道、签名与已知限制
- [flutter_miuix 文档](https://compose-miuix-ui.github.io/miuix/zh_CN/) —— 组件与玻璃体系参考

## 许可证

私有项目，`publish_to: none`（不发布到 pub.dev）。
