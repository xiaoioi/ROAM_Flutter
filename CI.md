# GitCode Actions 自动构建说明

仓库已配置 `.gitcode/workflows/build.yml`，在 GitCode 上可自动构建并上传：

- Android：`arm64-v8a` / `armeabi-v7a` 两个 release APK
- HarmonyOS NEXT：未签名 HAP（versionCode 与 pubspec.yaml 对齐）

## 1. 开启流水线

进入仓库 **设置 → 基础设置 → Actions 权限控制**，开启 Actions / 流水线。之后在仓库的「流水线 / Actions」页可以看到 **星环 Roam · 自动构建 APK / HAP**。

## 2. 触发

| 方式 | 条件 |
|---|---|
| 推送 | `main` 分支 |
| 标签 | `v*` |
| 合并请求 | 目标分支为 `main` |
| 手动 | 流水线页点「运行」 |

每次运行会先构建 APK、上传，再构建 HAP、上传。

## 3. 产物

在对应流水线运行详情的「制品 / Artifacts」里下载：

- `roam-apk`：`星环Roam-Android-v<版本>-arm64.apk`、`-arm32.apk`
- `roam-hap-unsigned`：`星环Roam-HarmonyOS-v<版本>-unsigned.hap`

HAP 是**未签名**包，不能直接 `hdc install`。需要签名时用 DevEco Studio 打开 `ohos/` → `Project Structure → Signing Configs → Automatically generate signature`，或在 `ohos/build-profile.json5` 填 `.p12/.cer/.p7b` 后 `flutter build hap --release --sign`。

## 4. 工具链（脚本自动安装）

`tool/ci_build.sh` 会在 runner 上准备：

| 组件 | 版本 / 地址 |
|---|---|
| Flutter | `oh-3.50.0-preview`（gitcode.com/openharmony-tpc/flutter_flutter），并打 `3.50.0` tag |
| JDK | 17（workflow 用 `setup-java` 设置） |
| Android SDK | cmdline-tools 13114758 + platform 36 + build-tools 36.0.0 + NDK 28.2.13676358 |
| DevEco | commandline-tools 5.1.0.840（HarmonyOS SDK API 18），来自 `repo.huaweicloud.com` |
| HAR 补丁 | `tool/patch_ohos_har.py`，首次 hap 构建后自动执行 |

首次运行需要下载约 4GB 工具链，耗时较长；后续由 `cache` 插件缓存 `~/.cache/roam-ci`、`~/.pub-cache`、`~/.gradle`，明显加快。需要换缓存目录可设置环境变量 `ROAM_CI_CACHE`。

## 5. 运行要求与排错

- 使用 GitCode 官方 `[ubuntu-latest, x64, large]`（8 核 32GB）；HAP 构建内存占用较高，`small` 规格可能不够。
- 脚本发现缺少 `curl/unzip/git/python3` 时会尝试 `apt-get` 安装；如果 runner 禁止 `sudo`，请改用自托管 runner 或预装这些命令。
- 国内网络下默认走 `pub.flutter-io.cn` / `storage.flutter-io.cn` 镜像；如需改回官方源，删掉 `tool/ci_build.sh` 里的 `PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL` 默认值。
- HAP 构建第一次失败是**正常现象**：那一趟只为让 ohpm 解包 `flutter_ohos.har`，随后脚本打 API 18 兼容补丁再构建一次。
- 版本号直接读 `pubspec.yaml`，升版本只需改 `version: x.y.z+build`，无需改 workflow。
