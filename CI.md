# 自动构建说明（GitCode Actions / GitHub Actions）

仓库已配置两套工作流：

| 平台 | 工作流文件 | 用途 |
|---|---|---|
| GitCode | `.gitcode/workflows/build.yml` | 构建产物上传为流水线制品 |
| GitHub | `.github/workflows/build-release.yml` | 构建产物直接发布到 GitHub Release |

两者共用 `tool/ci_build.sh`，构建内容一致：

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

## 6. GitHub Actions 发布 Release

`.github/workflows/build-release.yml` 在 **push `v*` 标签** 或 **Actions 页手动运行** 时触发，构建完成后用 `softprops/action-gh-release@v2` 创建 Release，把 `dist/` 下的 APK 与未签名 HAP 作为附件上传，并自动生成 Release Notes。

手动运行时可填 `tag`（如 `v1.0.31`）；留空则读 `pubspec.yaml` 的版本号生成 `v<版本>`。标签不存在时 Release Action 会基于当前提交自动创建。

所需权限：仓库 **Settings → Actions → General → Workflow permissions** 选 **Read and write permissions**，让内置的 `GITHUB_TOKEN` 能创建 Release。无需额外 Secret。

推荐发布流程：

```bash
# 改 pubspec.yaml 的 version，提交后打 tag
git tag v1.0.31
git push origin main --tags
```

GitHub 上首次运行同样要下载约 4GB 工具链；`actions/cache@v4` 会缓存工具链与依赖，后续运行显著加快。GitHub 免费 runner 的缓存上限是单仓库 10GB，这套工具链接近上限，若触发缓存淘汰只影响构建耗时，不影响结果。
