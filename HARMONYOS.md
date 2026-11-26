# 星环 Roam · HarmonyOS NEXT 适配说明

本目录已经包含一个可构建的鸿蒙工程 `ohos/`，构建产物在
`ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`。

当前状态：**能编译出完整 HAP（ArkTS + libflutter.so + libapp.so + flutter_assets）**，
但**没有华为账号做签名**，只能装到已开启调试的设备上，或者到 DevEco Studio
里自动签名后再安装。

> **版本对应**：v1.0.29 是两端同发（含网页权限 + URL Scheme）。
> v1.0.30 只做 Android（预测式返回），**鸿蒙跳过该版本**，下次打 HAP 直接用
> `1.0.31 / versionCode 1031`，不要回退到 1.0.30。

---

## 1. 工具链版本（本次实际使用的组合）

| 组件 | 版本 | 备注 |
|---|---|---|
| flutter_flutter | `oh-3.50.0-preview`（3.50.0，engine `d55dc4bd`） | gitcode.com/openharmony-tpc/flutter_flutter |
| DevEco 命令行工具 | `commandline-tools-linux-x64-5.1.0.840` | 含 HarmonyOS SDK 5.1.0 (API 18)、ohpm 5.1.3、hvigor 5.18.5、hdc |
| Node | 18.20.1（工具自带 `tool/node`） | |
| Dart | 3.14.0 | 随 flutter_flutter |
| target | `compatibleSdkVersion: 5.1.0(18)` | |

> SDK API 20/30 的 HarmonyOS 6.0 命令行工具目前拿不到公开直链；
> 仓库里 `ohos-sdk-...-6.0` 只能当 OpenHarmony SDK 用，hvigor 5.18.5 会报
> `00303168 SDK component missing`。所以这里统一按 API 18 编译。

## 2. 环境变量

```bash
FLUTTER_HOME=/workspace/flutter_ohos          # 鸿蒙版 Flutter SDK
TOOLS=/path/to/command-line-tools            # DevEco 命令行工具解压目录
export DEVECO_SDK_HOME=$TOOLS/sdk
export PATH=$TOOLS/hvigor/bin:$TOOLS/ohpm/bin:$TOOLS/tool/node/bin:$FLUTTER_HOME/bin:$PATH
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 3. 构建

```bash
cd roam_flutter
flutter pub get
flutter build hap --release
```

产物：`ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`

## 4. 签名与安装

未签名 HAP 无法直接 `hdc install`。两条路：

1. **DevEco Studio**：打开 `ohos/` 目录 → `File → Project Structure → Signing Configs`
   勾选 `Automatically generate signature`（需登录华为账号）→ Run / Build Hap(s)。
2. 已有的 `.p12` + `.cer` + `.p7b`：在 `ohos/build-profile.json5` 的
   `signingConfigs` 里填好，再执行 `flutter build hap --release --sign`（或直接
   `hvigorw assembleHap`）。

安装：

```bash
hdc install -r entry-default-signed.hap
```

## 5. 为适配做了什么

### 5.1 工程壳

`ohos/` 由 `flutter create --platforms ohos` 生成后改造：

- `AppScope/app.json5`：`bundleName = com.roam.explore`，版本号跟 Android 对齐；
- `AppScope/resources/base/media/app_icon.png`、`entry/.../media/icon.png`：换成应用图标；
- `entry/src/main/module.json5`：`INTERNET` + 网页权限（相机/麦克风/定位，见 5.8）；
- `build-profile.json5`：`compatibleSdkVersion/targetSdkVersion = 5.1.0(18)`。

### 5.2 插件（pub.dev 上的鸿蒙联邦实现）

```yaml
shared_preferences_ohos: ^2.2.0
path_provider_ohos: ^2.2.1
url_launcher_ohos: ^6.3.0
webview_flutter_ohos: ^3.15.0
```

这四行加在 `pubspec.yaml`，`ohos` 平台由 `GeneratedPluginRegistrant.ets`
自动注册；Android 构建仍然走原来的 `webview_flutter_android` / `*_android`。
`open_filex` 没有鸿蒙实现，`downloads_page.dart` 里已经兜底提示文件路径。

### 5.3 选图通道（对齐 Android 的 MainActivity.kt）

`ohos/entry/src/main/ets/entryability/EntryAbility.ets` 实现了
`org.roam.roam_flutter/photo_picker`：

| 方法 | 鸿蒙实现 |
|---|---|
| `pickImage` | `photoAccessHelper.PhotoViewPicker` 选图 → 复制到 `filesDir/wallpapers/custom_wallpaper_<ts>.jpg`，并清理旧图 |
| `pickFile` | `picker.DocumentViewPicker` → 复制到 `filesDir/imports/<原文件名>` |
| `openAppDetails` | 拉起系统设置的应用详情页 |

复制到沙箱是关键：`photoUris` 的临时授权出了回调就失效，`dart:io` 读不到。

### 5.4 嵌入层补丁 `tool/patch_ohos_har.py`

`flutter_ohos.har`（3.50 preview）是拿 HarmonyOS 6.0 写的，源码里直接用了
API 20/24/26 才有的符号，在 API 18 上编不过。脚本把这些调用点换成等价
本地声明或空实现（全部被 `AUTOFILL_SUPPORT_API = 26` / `canIUse` 挡在运行时之外）：

- `window.Position`、`window.ShowWindowOptions`、`SubWindowOptions.maximizeSupported`、
  `Window.isInFreeWindowMode`、`window.getGlobalWindowMode` / `GlobalWindowMode`；
- `KeyEvent.isCapsLockOn` / `isNumLockOn`；
- `autoFillManager.*`（ViewData / FillRequest / AutoFillCallback / SaveRequest …）；
- `CompetitionStrategy.DEFAULT`（`postInputEventWithStrategy` 的第二个参数）。

**注意**：`flutter pub get` 之后如果 ohpm 重新解包了 har，需要重跑一次
`python3 tool/patch_ohos_har.py .`，再 `flutter build hap`。

### 5.5 Dart 侧

- `about_page.dart`：`Platform.operatingSystem == 'ohos'` 时显示「HarmonyOS 设备 /
  HarmonyOS / ArkWeb 内核」，不再出现「Linux 桌面」；
- `downloads_page.dart`：`OpenFilex.open` 失败时提示文件位置。

### 5.6 桌面应用名（v1.0.29 修正）

`flutter create` 模板会在 `entry/src/main/resources/zh_CN|en_US/element/string.json`
里留下 `EntryAbility_label = "probe"`。系统按 `zh_CN` 匹配资源，桌面图标下面
就显示成 **probe**。现在三个语言目录的 `EntryAbility_label` 都是 **星环**
（`en_US` 为 `Roam`），`module.json5` 的 `label`／`AppScope` 的 `app_name`
指向同一套资源。

### 5.7 网页 URL Scheme 跳转（v1.0.29）

新增平台通道 `org.roam.roam_flutter/system`（`openExternal`）：

| 端 | 实现 |
|---|---|
| Android | `Intent(ACTION_VIEW)` / `Intent.parseUri(intent://)` → `startActivity`；先带 `CATEGORY_BROWSABLE` 试，失败去掉重试（个别 App 只声明 DEFAULT）；`market://` 无商店时退化成 Google Play 网页；`intent://` 自带 `S.browser_fallback_url` 时回原页 |
| 鸿蒙 | `startAbility({action:'ohos.want.action.viewData', uri})` → 补 `entity.system.browsable` 再试 → `openLink(appLinkingOnly:false)` 兜底 |

要点是**不预判**：Android 11 起 `canLaunchUrl` 受包可见性限制，
`<queries>` 没声明的 scheme 一律 false，所以以前点微信/支付宝链接没反应。
直接 `startActivity` 捕 `ActivityNotFoundException` 才可靠。

Dart 侧 `lib/services/system_bridge.dart` 负责 `intent://` 解析
（`scheme=` + `S.browser_fallback_url`），失败时给出「没有找到可以打开
xxx:// 的应用」提示，而不是静默失败。

### 5.8 网页权限申请（v1.0.29）

`lib/services/web_permission_service.dart` + `lib/ui/widgets/site_permission_prompt.dart`：

| 能力 | 触发方式 | 处理 |
|---|---|---|
| 相机 / 麦克风 | `WebView onPermissionRequest` | miuix 确认框 → 申请系统权限 → `grant()/deny()` |
| 定位 | `setGeolocationPermissionsPromptCallbacks` | 同上，返回 `GeolocationPermissionsResponse(allow, retain)` |
| 剪贴板 | 页面注入垫片，`navigator.clipboard.readText()` 抛 `NotAllowedError` 时才接管 | 确认框 → `readClipboard`（鸿蒙 pasteboard 会再弹系统确认） |

- 同一站点同一会话只问一次，可勾选「记住此网站的选择」，结果存
  `roam.site_permissions.v1`；
- 权限清单：Android `CAMERA / RECORD_AUDIO / ACCESS_FINE_LOCATION /
  ACCESS_COARSE_LOCATION`；鸿蒙 `CAMERA / MICROPHONE / LOCATION /
  APPROXIMATELY_LOCATION`（`module.json5` 里带 `reason` 与 `usedScene`）；
- 剪贴板垫片只做「兜底重写」，原本能读的站点行为不变。

## 6. 已知限制

1. **没有签名**：HAP 是 unsigned，装不了，需要在 DevEco 里配自动签名。
2. **没在真机跑过**：这个环境没有鸿蒙设备（`hdc list targets` 为空），
   玻璃着色器（`roam_glass.frag`，Impeller + Vulkan）、`webview_flutter_ohos`
   的平台视图、选图通道都只做到「编译通过」，运行时表现需要真机验证。
3. **SDK 只能到 API 18**：hvigor 5.18.5 不认 6.0 SDK；要用 API 20 得换 DevEco 6.0 的
   命令行工具（目前镜像站只到 5.1.0）。
4. **`flutter_flutter` 版本需要打 tag**：浅克隆没有 tag 时 `flutter --version` 会报
   `0.0.0-unknown`，pub 解析会失败；这里用 `git tag 3.50.0` 解决。
