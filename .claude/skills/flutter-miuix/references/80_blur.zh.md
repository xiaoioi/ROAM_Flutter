## 液态玻璃与模糊 Liquid Glass & Blur

**OS4 是独立材质层**：`MiuixGlass` / `MiuixGlassPanel`、35 组 GlassStyles、材质混色和 Glass 组件见 [110_os4](110_os4.zh.md)。本章的 TextureBlur / Highlight 是可复用的原基础，不等于完整 OS4 渲染。

本章涵盖 flutter_miuix 的液态玻璃效果实现：背景捕获（[MiuixBackdrop] / [MiuixLayerBackdrop] / [MiuixLayerBackdropCapture]）、纹理模糊（[MiuixTextureBlur]）、Bloom 高光边框（[MiuixHighlight] / [BloomStroke] / [LightSource]）以及模糊默认值（[MiuixBlurDefaults] / [BlurColors] / [BlurBlendMode]）。

[MiuixTextureBlur] 的高斯模糊交给 Skia/Impeller 的 `ui.ImageFilter.blur`（内部为可分离两趟 + 逐级降采样，无颗粒），sigma 取原版 `BLUR_RADIUS_TO_SIGMA=0.45`；颜色控制（亮度/对比度/饱和度）用等价的 `ColorFilter.matrix`。[MiuixHighlight] 的 bloom 边框仍基于预编译着色器 `shaders/miuix_bloom_stroke.frag`。

> 顶栏毛玻璃另有更简的做法：`MiuixTopAppBar(blurred: true)` 直接用 `BackdropFilter` 模糊身后内容，无需 backdrop 捕获（见「导航与脚手架」章）。
>
> 这只适用于**旧组件的 `blurred` 开关**。OS4 玻璃（`MiuixGlassPanel` / 栏遮罩 / 边缘渐隐）
> 不要自己套 `BackdropFilter`：它在 `ShaderMask` 的 saveLayer 内读不到下层内容，真机上会
> 表现为模糊彻底消失。OS4 的模糊一律走 `MiuixGlassPanel(backdrop: ...)` + `material`。

### 背景捕获

#### MiuixBackdrop

背景内容提供者的抽象基类，继承 `ChangeNotifier`。模糊组件（[MiuixTextureBlur] 等）通过它拿到"自己背后的内容"来做模糊。

| 字段 / 方法 | 类型 | 说明 |
|---|---|---|
| `isCoordinatesDependent` | `bool` | 是否需要布局坐标来正确定位（图层型 backdrop 为 true） |
| `snapshot` | `ui.Image?` | 当前可用于取样的背景快照；未捕获时为 null |
| `globalOffset` | `Offset?` | 背景快照在全局（窗口）坐标系中的左上角位置 |
| `pixelRatio` | `double` | 快照的设备像素比 |

#### MiuixLayerBackdrop

通过捕获的图层快照提供背景的 [MiuixBackdrop]。

| 字段 / 方法 | 类型 | 说明 |
|---|---|---|
| `MiuixLayerBackdrop()` | 构造 | 直接创建；需在 dispose 时释放 |
| `isCoordinatesDependent` | `bool` | 恒为 `true` |
| `updateSnapshot(image, globalOffset, pixelRatio)` | `void` | 由 [MiuixLayerBackdropCapture] 在每帧录制后调用，更新快照与坐标；旧快照在替换后被释放 |

#### MiuixLayerBackdropCapture

捕获子树渲染输出到 [backdrop] 供模糊组件当背景取样的 `SingleChildRenderObjectWidget`。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `backdrop` | `MiuixLayerBackdrop` | 必填 | 接收快照的 backdrop |
| `child` | `Widget` | 必填 | 应作为模糊背景出现的容器 |

**实现要点**：
- 本节点是重绘边界（`isRepaintBoundary = true`），Flutter 会为本节点分配一个 `OffsetLayer`。
- 在每帧 `paint` 后用 `addPostFrameCallback` 异步调用 `OffsetLayer.toImageSync` 同步出图，避免重录子树导致的图层重入。
- 出图后通过 `localToGlobal(Offset.zero)` 计算全局偏移，与 `pixelRatio` 一并交给 `backdrop.updateSnapshot`。

**示例：**
```dart
final backdrop = MiuixLayerBackdrop();

Widget tree = Column(
  children: [
    MiuixLayerBackdropCapture(
      backdrop: backdrop,
      child: const MyBackground(), // 应作为模糊背景出现的容器
    ),
    MiuixTextureBlur(
      backdrop: backdrop,
      blurRadius: 24,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Liquid glass'),
      ),
    ),
  ],
);
// ... 在 dispose 时 backdrop.dispose()
```

### 纹理模糊

#### MiuixTextureBlur

对 [backdrop] 提供的背景做高斯模糊并叠加子内容。模糊由 `ui.ImageFilter.blur` 完成（可分离两趟 + 逐级降采样，无颗粒），颜色控制用 `ColorFilter.matrix`。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `backdrop` | `MiuixBackdrop` | 必填 | 背景提供者 |
| `shape` | `ShapeBorder?` | `null` | 裁剪形状（null=矩形） |
| `blurRadius` | `double` | `MiuixBlurDefaults.blurRadius`（20.0） | 模糊半径（dp），自动夹到 `[0, maxBlurRadius]`；sigma = blurRadius × 0.45 |
| `colors` | `BlurColors` | `BlurColors()` | 模糊后颜色调整 |
| `enabled` | `bool` | `true` | false 时直接画子内容 |
| `child` | `Widget?` | `null` | 叠加在模糊层之上的子内容 |

**实现要点**：
- 取样背景快照时向外扩约 3σ margin（配 `TileMode.clamp`），让模糊边缘有真实邻域，避免边缘变暗；但绘制被裁进组件自身边界（`clipRect`），不会溢出（无 shape 时也不溢出）。
- 首帧快照就绪即出模糊（无异步着色器加载）。

### 边缘渐隐：progressiveTextureBlur（单张糊图 + 连续 alpha 遮罩）

官方 compose 版在 `miuix-blur` 里：

```
Modifier.progressiveTextureBlur(backdrop, shape, blurRadius,
    gradient = ProgressiveBlur.Top, noiseCoefficient, colors, ...)
  → computeProgressiveGradient()   归一化成 gradVec + gradOffset
  → createProgressiveBlurEffect()  逐像素 radius = maxRadius * (1 - smooth)
  → 半径随位置变化的可分离高斯（H/V 两 pass RenderEffect）
```

`flutter_miuix` 1.4.0 没移植。**不要用 FragmentShader 自己卷**：40 个螺旋
采样点近似二维高斯，半径一大采样就稀，画面会被拆成错位的块（「像碎成好几块
散开」），而且每帧整条带子跑一遍逐像素循环，延迟也高。

**更不要「按半径分档、每档 blur 一次再叠加」**（v1.0.38~v1.0.40 的弯路）：
文字是高频高对比内容，两张清晰度不同的图叠在一起就是双重轮廓，档位交接处
还会浮出台阶，半透明档位合成时 alpha 补不满、下面内容透上来（「越靠边越透明」）。
7 档 = 7 次 `saveLayer` + 7 次全屏 `ImageFilter.blur`，真机直接卡死。

项目内实现（`lib/ui/widgets/progressive_texture_blur.dart`）：

- **只画一张图**：按满强度 `sigma = blurRadius * .5 + .5` 模糊一次。
- 再用一条连续 alpha 遮罩把它擦到 0：`0..startFraction` 恒为 1（完全不透明），
  `startFraction..endFraction` 按 `pow(1-u, curve)` 淡出，之后 0。
  只有一份图像 → 没有重影、没有档位断层；顶部 alpha=1 → 看不见后面的内容；
  过渡段半透明 → 正文透上来，观感是「由清晰逐渐起雾」，连续不断。
- 遮罩用 `ui.Gradient.linear` **显式像素坐标**：`Alignment` 渐变在非正方形
  区域上把 stops 映射到 `[-.5,.5]`，遮罩会整体错位（表现为「上面反而清晰」）。
- `saveLayer(dst)` 隔离 + `clipRect(带子)`，遮罩用 `dstIn`。全流程 1 次
  `saveLayer` + 1 次 blur，开销只和带子面积有关。

**顶栏带子的形状**：`startFraction` 要落在栏底下沿之外——顶栏 `Positioned` 的
`bottom` 给 `-56`（而不是官方的 24 overhang），前 62% 是满强度（盖住状态栏 +
栏本身），最后 38% 在栏底以下的正文上展开过渡。否则满强度区被压没，栏内会
透出正文。

两个实测坑：
- `canvas.saveLayer(bounds, Paint())` 的 bounds 不能取带子本身，否则
  `drawImageRect` 的 `imageFilter` 会连同输入一起被裁掉（一点没糊）。用采样区（含 2σ 外扩的 dst）。
- 不要用裸 `BackdropFilter`（`ShaderMask`/`saveLayer` 后读不到下层像素，整条带子透明）。

**性能**：`MiuixLayerBackdropCapture` 是常驻组件，每帧 `toImageSync` 一次快照，
`pixelRatio` 必须显式给 `1`（3x 屏上每帧数据量 ~13MB → ~1.4MB，这是滚动卡顿
的主因；玻璃本身有高斯，肉眼分辨不出 1x 与 3x）。

### Bloom 高光边框### Bloom 高光边框### Bloom 高光边框### Bloom 高光边框### Bloom 高光边框

圆角矩形 SDF + 3D 半球 rim 法线 + 方向光，画出被照亮的玻璃边缘；`BlendMode.plus` 叠加。

#### LightPosition

光源的 3D 位置（归一化 UV）。

| 字段 | 类型 | 说明 |
|---|---|---|
| `x` / `y` | `double` | `[0,1]` 内的 UV 位置，`(0.5, 0.7)` 为参考原点（放这里无贡献） |
| `z` | `double` | 有符号深度；负值置于表面之后 |

着色器把 `(x-0.5, y-0.7, z)` 归一化为方向。

#### LightSource

一个方向光源。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `position` | `LightPosition` | 必填 | 光源位置 |
| `color` | `Color` | `Color(0xFFFFFFFF)` | 光色 |
| `intensity` | `double` | `1.0` | 强度 |

#### BloomStroke

边缘 bloom 描边的着色模型。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `color` | `Color` | `Color(0x0DFFFFFF)`（White @ 0.05） | 平铺描边色（alpha 缩放描边贡献） |
| `blendMode` | `BlendMode` | `BlendMode.plus` | 合成模式 |
| `innerBlurRadius` | `double` | `2.8` | 内发光深度（dp） |
| `primaryLight` | `LightSource` | 见下 | 主光源 |
| `secondaryLight` | `LightSource` | 见下 | 副光源 |
| `dualPeak` | `bool` | `false` | 每光是否产生两个对峰（Apple 风镜面扫光） |

默认主光源：`LightPosition(0.5, 0.5, -0.5)`、intensity `0.4`；副光源：`LightPosition(0.5, 0.8, -0.5)`、intensity `0.25`。

**6 个 GlassStroke 预设**：

| 静态常量 | innerBlurRadius | 主光 intensity | 副光 intensity |
|---|---|---|---|
| `glassStrokeBigLight` | 3.5 | 0.3 | 0.2 |
| `glassStrokeMiddleLight` | 2.8 | 0.4 | 0.25 |
| `glassStrokeSmallLight` | 2.6 | 0.6 | 0.35 |
| `glassStrokeBigDark` | 1.7 | 0.4 | 0.25 |
| `glassStrokeMiddleDark` | 2.0 | 0.5 | 0.25 |
| `glassStrokeSmallDark` | 2.3 | 0.6 | 0.25 |

#### Highlight

高光配置。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `width` | `double` | `0.8` | 描边带宽（dp） |
| `alpha` | `double` | `1.0` | 整体不透明度 |
| `style` | `BloomStroke` | `BloomStroke.glassStrokeMiddleLight` | 着色模型 |

**6 个静态预设**：`Highlight.glassStrokeBigLight` / `glassStrokeMiddleLight` / `glassStrokeSmallLight` / `glassStrokeBigDark` / `glassStrokeMiddleDark` / `glassStrokeSmallDark`，分别封装对应 `BloomStroke` 预设。

`Highlight.defaultHighlight = Highlight.glassStrokeMiddleLight`（标准浅色卡片默认）。

#### MiuixHighlight

在子内容之上绘制 bloom 高光边框的 `StatefulWidget`。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `highlight` | `Highlight` | `Highlight.defaultHighlight` | 高光配置 |
| `shape` | `ShapeBorder?` | `null` | 圆角形状（读取四角半径，null=胶囊/全圆角） |
| `child` | `Widget?` | `null` | 子内容；null 时占满父级 |

**实现要点**：
- 着色器程序单例异步加载（`packages/flutter_miuix/shaders/miuix_bloom_stroke.frag`），未就绪时直接画子内容。
- `width <= 0` 或 `alpha <= 0` 时跳过绘制。
- 通过 `RoundedRectangleBorder` 解析四角像素半径，否则按短边一半作为全圆角。
- 当前实现为 single-peak 变体（默认 `dualPeak=false`，覆盖全部内置预设）。

### 模糊默认值与颜色配置

#### MiuixBlurDefaults

模糊效果默认值。`MiuixBlurDefaults._()` 私有构造，全部为 `static` 字段。

| 常量 | 值 | 说明 |
|---|---|---|
| `blurRadius` | `20.0` | 默认模糊半径（dp） |
| `noiseCoefficient` | `0.0045` | 默认噪声抖动系数（抗色带） |
| `progressiveNoiseCoefficient` | `0.0` | progressive blur 的默认噪声系数（0=禁用） |
| `maxBlurRadius` | `150.0` | 最大模糊半径（dp） |
| `blurRadiusToSigma` | `0.45` | 模糊半径 → 高斯 sigma 的转换系数 |
| `blurKernelReach` | `13` | 模糊核触及范围（源像素） |

#### `MiuixBlurDefaults.blurColors({blendColors, brightness, contrast, saturation})` → `BlurColors`

便捷构造 [BlurColors]。

#### BlurColors

模糊后应用的颜色配置。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `blendColors` | `List<BlendColorEntry>` | `const []` | 按顺序叠加在模糊背景上 |
| `brightness` | `double` | `0.0` | 亮度调整 `[-1,1]`，0 无变化 |
| `contrast` | `double` | `1.0` | 对比度乘子，1 无变化 |
| `saturation` | `double` | `1.0` | 饱和度乘子，1 无变化 |

实现了 `==` / `hashCode`。

#### BlendColorEntry

叠加在模糊背景上的单个颜色 blend。

| 参数 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `color` | `Color` | 必填 | 叠加颜色 |
| `mode` | `BlurBlendMode` | `BlurBlendMode.srcOver` | blend 模式 |

实现了 `==` / `hashCode`。

#### BlurBlendMode

模糊颜色 blend 模式。`value` 为原始模式标识。

- `0-28`：标准 `SkBlendMode`（GPU 硬件处理），与 Flutter `BlendMode` 一一对应。
- `>=100`：扩展自定义模式（Lab / 线性光等，由 runtime shader 处理）。

**标准模式**（节选）：`clear=0`、`src=1`、`dst=2`、`srcOver=3`、`dstOver=4`、`srcIn=5`、`dstIn=6`、`srcOut=7`、`dstOut=8`、`srcAtop=9`、`dstAtop=10`、`xor=11`、`plus=12`、`modulate=13`、`screen=14`、`overlay=15`、`darken=16`、`lighten=17`、`colorDodge=18`、`colorBurn=19`、`hardLight=20`、`softLight=21`、`difference=22`、`exclusion=23`、`multiply=24`、`hue=25`、`saturationMode=26`、`colorMode=27`、`luminosity=28`。

**扩展模式**（节选）：`linearLight=100`、`linearLightWithGreyscale=101`、`miDifference=102`、`labLightenWithGreyscale=103`、`labDarkenWithGreyscale=105`、`lab=106`、`linearLightLab=107`、`miColorDodge=118`、`miColorBurn=119`、`plusDarker=120`、`plusLighter=121`、`alphaBlend=200`、`miSaturation=201`、`miBrightness=202`、`miLuminance=203`。

> 扩展模式需要 runtime shader 支持，当前阶段在 `MiuixTextureBlur` 的 `blendColors` 中会被跳过（仅标准模式 0-28 通过 Flutter `BlendMode` 直接叠色块实现）。

#### `miuixStandardBlendMode(mode)` → `BlendMode?`

把 [BlurBlendMode] 映射到 Flutter 原生 [BlendMode]（仅标准模式 0-28）。扩展模式（>=100）返回 null，需 runtime shader。

### 完整示例：液态玻璃卡片

```dart
class _GlassState extends State<MyGlass> {
  final _backdrop = MiuixLayerBackdrop();

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景内容（应被模糊）
        Positioned.fill(
          child: MiuixLayerBackdropCapture(
            backdrop: _backdrop,
            child: const MyScrollableContent(),
          ),
        ),
        // 毛玻璃卡片 + bloom 高光边框
        Center(
          child: SizedBox(
            width: 220, height: 140,
            child: MiuixHighlight(
              highlight: Highlight.glassStrokeMiddleLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: MiuixTextureBlur(
                backdrop: _backdrop,
                shape: const MiuixSquircleBorder(cornerRadius: 28),
                blurRadius: 24,
                colors: MiuixBlurDefaults.blurColors(saturation: 1.5),
                child: const Center(child: Text('Liquid glass')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

> 顶栏毛玻璃优先用 `MiuixTopAppBar(blurred: true)`——无需 backdrop 捕获。
