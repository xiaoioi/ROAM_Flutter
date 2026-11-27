#!/usr/bin/env bash
# 星环 Roam · GitCode Action 一站式构建脚本
# 用法: bash tool/ci_build.sh android | bash tool/ci_build.sh hap | bash tool/ci_build.sh check
set -euo pipefail

TARGET="${1:-}"
case "$TARGET" in
  android|hap|check) ;;
  *) echo "用法: $0 <android|hap|check>" >&2; exit 2 ;;
esac

log() { printf '\n[roam-ci] %s\n' "$*"; }

# ---------------------------------------------------------------- 基础命令
ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 && return
  log "安装缺失命令: $1"
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq "$1"
  else
    apt-get update -qq && apt-get install -y -qq "$1"
  fi
}
ensure_cmd curl
ensure_cmd unzip
ensure_cmd git
ensure_cmd python3

# ---------------------------------------------------------------- 定位仓库
find_repo_root() {
  local dir="$PWD"
  for _ in 1 2 3 4; do
    if [[ -f "$dir/pubspec.yaml" && -d "$dir/lib" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "[roam-ci] 找不到仓库根目录（需要 pubspec.yaml + lib/），当前目录: $PWD" >&2
  exit 1
}
REPO_ROOT="$(find_repo_root)"
cd "$REPO_ROOT"
log "仓库目录: $REPO_ROOT"

CACHE_ROOT="${ROAM_CI_CACHE:-$HOME/.cache/roam-ci}"
mkdir -p "$CACHE_ROOT"

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"
# 鸿蒙引擎制品走独立的华为 OBS 源，不受 FLUTTER_STORAGE_BASE_URL 影响。
export FLUTTER_OHOS_STORAGE_BASE_URL="${FLUTTER_OHOS_STORAGE_BASE_URL:-https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com}"

# ---------------------------------------------------------------- Flutter
ensure_flutter() {
  local dir="$CACHE_ROOT/flutter_ohos"
  if [[ ! -x "$dir/bin/flutter" ]]; then
    log "首次构建：克隆 flutter_flutter (oh-3.50.0-preview)，约 1GB"
    rm -rf "$dir"
    git clone --depth 1 --branch oh-3.50.0-preview \
      https://gitcode.com/openharmony-tpc/flutter_flutter.git "$dir"
  else
    log "复用缓存的 Flutter: $dir"
  fi
  # 浅克隆没有 tag 时 flutter --version 会变成 0.0.0-unknown，pub 解析会失败。
  if ! git -C "$dir" show-ref --verify --quiet refs/tags/3.50.0; then
    git -C "$dir" tag -f 3.50.0 HEAD
  fi
  git config --global --add safe.directory "$dir" >/dev/null 2>&1 || true
  FLUTTER_HOME="$dir"
  export PATH="$FLUTTER_HOME/bin:$PATH"
  flutter config --no-analytics >/dev/null 2>&1 || true
  flutter --version
}

# ---------------------------------------------------------------- Android SDK
ensure_android_sdk() {
  local sdk="$CACHE_ROOT/android-sdk"
  local manager="$sdk/cmdline-tools/latest/bin/sdkmanager"
  if [[ ! -x "$manager" ]]; then
    log "首次构建：下载 Android 命令行工具 (13114758)"
    rm -rf "$sdk/cmdline-tools" "$CACHE_ROOT/cmdline-tools-tmp"
    mkdir -p "$sdk/cmdline-tools" "$CACHE_ROOT/cmdline-tools-tmp"
    curl -fL --retry 3 --connect-timeout 30 \
      https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip \
      -o "$CACHE_ROOT/cmdline-tools.zip"
    unzip -q "$CACHE_ROOT/cmdline-tools.zip" -d "$CACHE_ROOT/cmdline-tools-tmp"
    mv "$CACHE_ROOT/cmdline-tools-tmp/cmdline-tools" "$sdk/cmdline-tools/latest"
    rm -rf "$CACHE_ROOT/cmdline-tools-tmp"
  else
    log "复用缓存的 Android SDK: $sdk"
  fi
  if [[ -z "${JAVA_HOME:-}" ]] && command -v javac >/dev/null 2>&1; then
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
    export JAVA_HOME
  fi
  export ANDROID_HOME="$sdk"
  export ANDROID_SDK_ROOT="$sdk"
  export PATH="$sdk/cmdline-tools/latest/bin:$sdk/platform-tools:$PATH"
  yes | sdkmanager --sdk_root="$sdk" --licenses >/dev/null 2>&1 || true
  log "安装 Android platform / build-tools / NDK"
  sdkmanager --sdk_root="$sdk" \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" \
    "ndk;28.2.13676358"
}

# ---------------------------------------------------------------- DevEco / HarmonyOS SDK
ensure_deveco() {
  local tools="$CACHE_ROOT/deveco-tools"
  # commandline-tools zip 的顶层目录是 command-line-tools/，解压后 SDK 位于
  # $tools/command-line-tools/sdk；但有人为准备的缓存直接放到 $tools/sdk。
  # 两种布局都要认，否则 DEVECO_SDK_HOME 指向不存在的目录，flutter pub get
  # 会报 "No Hmos SDK found"。
  local root=""
  for candidate in "$tools/command-line-tools" "$tools"; do
    if [[ -d "$candidate/sdk" && -x "$candidate/hvigor/bin/hvigorw" ]]; then
      root="$candidate"
      break
    fi
  done
  if [[ -z "$root" ]]; then
    log "首次构建：下载 DevEco commandline-tools 5.1.0.840（约 2.1GB）"
    rm -rf "$tools"
    mkdir -p "$tools"
    curl -fL --retry 3 --connect-timeout 30 \
      https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip \
      -o "$CACHE_ROOT/deveco-tools.zip"
    unzip -q "$CACHE_ROOT/deveco-tools.zip" -d "$tools"
    for candidate in "$tools/command-line-tools" "$tools"; do
      if [[ -d "$candidate/sdk" && -x "$candidate/hvigor/bin/hvigorw" ]]; then
        root="$candidate"
        break
      fi
    done
  else
    log "复用缓存的 DevEco 工具链: $root"
  fi
  if [[ -z "$root" ]]; then
    echo "[roam-ci] 解压后未找到有效的 DevEco tools（sdk/ + hvigor/bin/hvigorw）" >&2
    find "$tools" -maxdepth 3 -type d | head -30 >&2
    exit 1
  fi
  log "DevEco tools 根目录: $root"
  export DEVECO_SDK_HOME="$root/sdk"
  export HOS_SDK_HOME="$root/sdk"
  export OHOS_SDK_HOME="$root/sdk"
  export PATH="$root/hvigor/bin:$root/ohpm/bin:$root/tool/node/bin:$PATH"
  # Flutter 的 hvigor 调用需要 node，显式给出 NODE_HOME。
  export NODE_HOME="$root/tool/node"
  hvigorw --version 2>/dev/null | head -3 || true
}

# ---------------------------------------------------------------- 构建
ensure_flutter
# 即使只打 APK，这个 Flutter fork 在 pub get 阶段也会为 ohos 插件写
# ohos/local.properties，缺少 HOS_SDK_HOME 会直接 ToolExit。
ensure_deveco

if [[ "$TARGET" == "android" ]]; then
  ensure_android_sdk
fi

log "flutter pub get"
flutter pub get

# check：只做静态分析与测试，不构建产物。供 .github/workflows/ci.yml 在每次
# push / PR 时调用；仍然复用上面同一套 Flutter + DevEco 工具链与缓存。
if [[ "$TARGET" == "check" ]]; then
  log "flutter analyze lib test"
  flutter analyze lib test
  log "flutter test"
  flutter test
  log "检查完成"
  exit 0
fi

VERSION="$(awk -F'[:+]' '/^version:/ {gsub(/[ \t]/, "", $2); print $2; exit}' pubspec.yaml)"
[[ -n "$VERSION" ]] || { echo "[roam-ci] 无法从 pubspec.yaml 读取版本号" >&2; exit 1; }
log "版本: $VERSION"

mkdir -p dist
case "$TARGET" in
  android)
    log "flutter build apk --release --split-per-abi"
    flutter build apk --release --split-per-abi
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
      "dist/星环Roam-Android-v${VERSION}-arm64.apk"
    cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
      "dist/星环Roam-Android-v${VERSION}-arm32.apk"
    ;;
  hap)
    # 第一次构建让 ohpm 把 flutter_ohos.har 解包出来；该 har 用 API 20+ 编写，
    # 在 API 18 上预期会因符号缺失失败，所以这里允许失败后再打补丁。
    log "首次 hap 构建（生成 oh_modules，允许失败）"
    flutter build hap --release || true
    [[ -d ohos/oh_modules ]] || {
      echo "[roam-ci] ohpm 未生成 ohos/oh_modules，无法继续打补丁" >&2
      exit 1
    }
    log "给 flutter_ohos.har 打 API 18 兼容补丁"
    python3 tool/patch_ohos_har.py .
    log "flutter build hap --release（打补丁后）"
    # 未配置签名时 flutter/hvigor 会以非零退出并提示去 DevEco 配置签名，
    # 但 unsigned HAP 已经产出。这里以产物是否存在为准。
    if ! flutter build hap --release; then
      log "构建命令返回非零（通常是未签名提示），检查 unsigned HAP 是否已生成"
    fi
    HAP_PATH="ohos/entry/build/default/outputs/default/entry-default-unsigned.hap"
    [[ -s "$HAP_PATH" ]] || {
      echo "[roam-ci] 未找到 unsigned HAP: $HAP_PATH" >&2
      exit 1
    }
    cp "$HAP_PATH" "dist/星环Roam-HarmonyOS-v${VERSION}-unsigned.hap"
    ;;
esac

log "产物："
ls -lh dist/
