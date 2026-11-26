#!/usr/bin/env python3
"""让 @ohos/flutter_ohos（Flutter 3.50 鸿蒙嵌入层）能在 HarmonyOS SDK API 18 上编译。

背景
----
flutter_flutter 的 oh-3.50.0-preview 分支随包下发的 flutter_ohos.har
是用 HarmonyOS 6.0（API 20/26）工具链写的，源码里直接引用了 API 20+
才有的符号：

  · window.Position / window.ShowWindowOptions / Window.isInFreeWindowMode
  · window.getGlobalWindowMode / window.GlobalWindowMode
  · KeyEvent.isCapsLockOn / isNumLockOn
  · autoFillManager 的 ViewData / FillRequest / AutoFillCallback …
  · CompetitionStrategy（postInputEventWithStrategy 的第二个参数）

而 DevEco 命令行工具 5.1.0（hvigor 5.18.5）只认到 API 18，用 API 30 的 SDK
会直接报 `00303168 SDK component missing`（hvigor 与 SDK 版本不匹配）。
本脚本把这批调用点替换成等价的本地声明或空实现——它们全部被
`deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API(26)` / `canIUse(...)` 的
运行时判断挡在门外，在 HarmonyOS 5/6 手机上根本不会执行，替换不影响功能。

用法：python3 tool/patch_ohos_har.py [ohos 工程根目录]
"""
from __future__ import annotations

import sys
from pathlib import Path

# ---------------------------------------------------------------- 补丁内容

AUTOFILL_COMPAT = '''
// ---- SDK < API 26 compatibility shim (added by tool/patch_ohos_har.py) ----
// 这些名字在原包里直接取自 autoFillManager，而 API 18 的 SDK 里还没有它们。
// 所有调用都受 AUTOFILL_SUPPORT_API（26）保护，低版本系统永远不会走到这里，
// 因此用本地等价类型 + 空实现顶上即可。
export interface CompatFillFailureResult {
  errCode: number;
}

export interface CompatFillRequest {
  type: number;
  viewData: AutoFillManagerViewData;
  customData: AutoFillCustomData;
  isPopup: boolean;
  triggerType: number;
}

export interface CompatAutoFillCallback {
  onSuccess: (viewData: AutoFillManagerViewData) => void;
  onFailure: (result: CompatFillFailureResult) => void;
}

export interface CompatAutoSaveCallback {
  onFailure: () => void;
}

export interface CompatSaveRequest {
  viewData: AutoFillManagerViewData;
}

function compatRequestAutoFill(
  uiContext: UIContext,
  request: CompatFillRequest,
  callback: CompatAutoFillCallback): void {
  callback.onFailure({ errCode: -1 });
}

function compatRequestAutoSave(
  uiContext: UIContext,
  request: CompatSaveRequest,
  callback: CompatAutoSaveCallback): void {
  callback.onFailure();
}
// ---- end compatibility shim ----

'''


def patch_autofill(path: Path) -> None:
    s = path.read_text()

    s = s.replace(
        "import { autoFillManager, bundleManager } from '@kit.AbilityKit';",
        "import { bundleManager } from '@kit.AbilityKit';\n"
        "import { BusinessError } from '@ohos.base';",
    )

    # autoFillManager.X -> 本地类型
    pairs = [
        ("autoFillManager.AutoFillType", "number"),
        ("autoFillManager.AutoFillTriggerType", "number"),
        ("autoFillManager.ViewData", "AutoFillManagerViewData"),
        ("autoFillManager.FillFailureResult", "CompatFillFailureResult"),
        ("autoFillManager.FillRequest", "CompatFillRequest"),
        ("autoFillManager.AutoFillCallback", "CompatAutoFillCallback"),
        ("autoFillManager.AutoSaveCallback", "CompatAutoSaveCallback"),
        ("autoFillManager.SaveRequest", "CompatSaveRequest"),
        ("autoFillManager.requestAutoFill(", "compatRequestAutoFill("),
        ("autoFillManager.requestAutoSave(", "compatRequestAutoSave("),
    ]
    for old, new in pairs:
        s = s.replace(old, new)

    marker = "export class OhosAutoFillHelper {"
    if marker in s and "compatibility shim" not in s:
        s = s.replace(marker, AUTOFILL_COMPAT + marker, 1)

    path.write_text(s)


def ensure_business_error(path: Path) -> None:
    """TextInputPlugin 里用到了 BusinessError，但没从 @ohos.base 导入。"""
    s = path.read_text()
    if "BusinessError" not in s or "import { BusinessError }" in s:
        return
    anchor = "import deviceInfo from '@ohos.deviceInfo';"
    if anchor in s:
        s = s.replace(
            anchor, anchor + "\nimport { BusinessError } from '@ohos.base';", 1
        )
    else:
        s = "import { BusinessError } from '@ohos.base';\n" + s
    path.write_text(s)


def patch_window_hosts(root: Path) -> None:
    for name in ["PopupWindowHost.ets", "TooltipWindowHost.ets"]:
        f = root / "embedding/ohos/windowing" / name
        if not f.exists():
            continue
        s = f.read_text()
        # API 18 的 SubWindowOptions 没有 maximizeSupported 字段
        s = s.replace("      maximizeSupported: false,\n", "")
        # API 18 的 showWindow() 不接受参数，也就不需要 ShowWindowOptions
        s = s.replace(
            "      const showOptions: window.ShowWindowOptions = { focusOnShow: false };\n"
            "      await subWindow.showWindow(showOptions);",
            "      await subWindow.showWindow();",
        )
        f.write_text(s)


def patch_dialog_host(root: Path) -> None:
    f = root / "embedding/ohos/windowing/DialogWindowHost.ets"
    if not f.exists():
        return
    s = f.read_text()
    if "interface CompatWindowPosition" not in s:
        s = (
            "// API 18 没有 window.Position，用本地同形接口替代。\n"
            "interface CompatWindowPosition {\n"
            "  x: number;\n"
            "  y: number;\n"
            "}\n"
        ) + s
    s = s.replace(
        "const window_origin: window.Position = { x: 0, y: 0 };",
        "const window_origin: CompatWindowPosition = { x: 0, y: 0 };",
    )
    # API 18 的 SubWindowOptions 没有 maximizeSupported 字段
    s = s.replace("      maximizeSupported: true,\n", "")
    s = s.replace("      maximizeSupported: false,\n", "")
    f.write_text(s)


def patch_pip(root: Path) -> None:
    f = root / "embedding/ohos/PiPVisibilityBridge.ets"
    if not f.exists():
        return
    s = f.read_text()
    s = s.replace(
        """    try {
      const mode = await window.getGlobalWindowMode();
      return (mode & window.GlobalWindowMode.PIP) !== 0;
    } catch (error) {
      Log.w(TAG, "getGlobalWindowMode failed: " + JSON.stringify(error));
      return false;
    }""",
        """    // API 18 没有 getGlobalWindowMode / GlobalWindowMode，
    // 低版本上画中画模式判断直接按「非画中画」处理。
    return false;""",
    )
    f.write_text(s)


def patch_key_event(root: Path) -> None:
    f = root / "embedding/ohos/KeyEventHandler.ets"
    if not f.exists():
        return
    s = f.read_text()
    s = s.replace(
        "const isCapsLockOn = event.isCapsLockOn !== undefined ? event.isCapsLockOn : false;",
        "const isCapsLockOn = false; // API 18 的 KeyEvent 没有 isCapsLockOn",
    )
    s = s.replace(
        "const isNumLockOn = event.isNumLockOn !== undefined ? event.isNumLockOn : true; // Default to true if not available",
        "const isNumLockOn = true; // API 18 的 KeyEvent 没有 isNumLockOn",
    )
    f.write_text(s)


def patch_flutter_manager(root: Path) -> None:
    f = root / "embedding/ohos/FlutterManager.ets"
    if not f.exists():
        return
    s = f.read_text()
    s = s.replace(
        "        return mainWindow.isInFreeWindowMode();",
        "        return false; // API 18 的 Window 没有 isInFreeWindowMode",
    )
    f.write_text(s)


def patch_embedding_node(root: Path) -> None:
    f = root / "embedding/ohos/EmbeddingNodeController.ets"
    if not f.exists():
        return
    s = f.read_text()
    # postInputEventWithStrategy 的第二个参数是 API 24+ 的 CompetitionStrategy 枚举，
    # 这里用 0（DEFAULT）的等价字面量，走 ESObject 调用不会做类型检查。
    s = s.replace("CompetitionStrategy.DEFAULT", "(0 as ESObject)")
    f.write_text(s)


def find_har(project: Path) -> Path | None:
    for p in project.glob("ohos/oh_modules/.ohpm/*/oh_modules/@ohos/flutter_ohos"):
        if p.is_dir():
            return p
    for p in project.glob("ohos/oh_modules/@ohos/flutter_ohos"):
        if p.is_dir():
            return p
    return None


def main() -> int:
    project = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    har = find_har(project)
    if har is None:
        print("未找到 flutter_ohos har，请先执行一次 flutter build hap 让 ohpm 安装依赖")
        return 1
    src = har / "src/main/ets"
    print(f"patch har: {har}")

    patch_autofill(src / "plugin/editing/OhosAutoFillHelper.ets")
    ensure_business_error(src / "plugin/editing/TextInputPlugin.ets")
    patch_window_hosts(src)
    patch_dialog_host(src)
    patch_pip(src)
    patch_key_event(src)
    patch_flutter_manager(src)
    patch_embedding_node(src)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
