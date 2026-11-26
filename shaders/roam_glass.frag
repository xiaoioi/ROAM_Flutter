#version 460 core
#include <flutter/runtime_effect.glsl>

// ─────────────────────────────────────────────────────────────────────────────
// Roam OS4 柔光玻璃 · 官方链路完整移植
//
// 本文件的每一段都可逐行对回 HyperOS 主体玻璃 shader：
//
//   倒角剖面 smooth5 ─→ 法线 ─→ 折射(miRefract) / 反射 ─→ gcr 乘法调色
//   ─→ 方向光 hsvv ─→ pow gate
//
// 与上一版最大的不同，也是之前"怎么调都不像"的根因：
//
//   1. 压暗不是手写的 `*= 0.8`，而是 gcr 链自然产生的。
//      gcr = mix(1, 大模糊色, ratio)，ratio≈0.73 → 内部乘 0.78；
//      再叠 pow(colorPow=1.2) 得到 0.78^1.2≈0.75。真机 0.700→0.580。
//   2. 边缘那圈亮线不是白描边，而是 hsvv 的对比扩展：
//      (c+k)*g-k，深色底 k→1、g→1.75，把倒角带"拉开"而不是"刷白"。
//   3. darker 染的是**亮部**（smoothstep(0.6,1,luma)），不是暗部。
//      我上一版把方向搞反了。
//   4. 反射位移可以到 reflectOffset(200dp) 量级，不能夹到带内——
//      玻璃边缘"卷进一大片背景"正是它造成的。
//   5. 饱和度是线性插值系数（2.0 常见），brightness 是**直接相加**。
//      它们不会爆白，因为后面还有 gcr 乘法与 pow 两次压暗。
// ─────────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;        // 组件逻辑尺寸
uniform vec2 uOrigin;      // 组件左上角在快照纹理中的位置（逻辑坐标）
uniform vec2 uTexSize;     // 快照纹理的逻辑尺寸
uniform vec4 uRadii;       // 左上 右上 右下 左下

uniform sampler2D uBackdrop;     // 折射 / 反射取样（小模糊）
uniform sampler2D uBackdropBig;  // 体积色（大模糊，对应 uWallpaperCoarse）

// 几何 / 光学
uniform float uEdgePx;           // edgeWidth，逻辑 px
uniform float uEdgePow;
uniform float uThicknessPx;
uniform float uReflectOffsetPx;
uniform float uIOR;
uniform float uReflStrength;
uniform float uReflLighten;
uniform float uInnerBottom;
uniform float uLightFalloff;

// 方向光
uniform vec3  uLightDir;
uniform float uAngleK;
uniform float uLightIntensity;
uniform float uLightOpposite;
uniform float uNmlZAAThreshold;

// 调色
uniform float uDarker;
uniform vec3  uDarkerColor;
uniform vec2  uDarkerRange;
uniform vec4  uLuminance;        // 三次曲线 4 个采样值
uniform float uLuminanceAmount;
uniform float uSaturation;
uniform float uBrightness;
uniform float uBgSat;
uniform float uBgBri;
uniform float uInnerWhite;
uniform float uInnerMix;
uniform float uBurn;
uniform float uColorPow;
uniform float uAlpha;
uniform vec4  uTint;             // rgb = 染色, a = 混合权重
uniform float uUnshade;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// ───────────────────────────────────────────────────────────── 采样
//
// GLSL / SkSL 都不允许把 sampler 当函数参数传，所以这里写成两个具名函数，
// 而不是 sampleAt(local, tex) 的通用形式。

// 快照边缘之外是透明像素；直接取 rgb 会把"没有内容"当成纯黑喂给调色。
vec3 sampleLevel(vec2 local) {
  vec2 uv = (clamp(local, vec2(0.5), uTexSize - 0.5) + uOrigin) / uTexSize;
  vec4 s = texture(uBackdrop, uv);
  return s.a > 0.004 ? s.rgb / s.a : s.rgb;
}

vec3 sampleCoarse(vec2 local) {
  vec2 uv = (clamp(local, vec2(0.5), uTexSize - 0.5) + uOrigin) / uTexSize;
  vec4 s = texture(uBackdropBig, uv);
  return s.a > 0.004 ? s.rgb / s.a : s.rgb;
}

// ───────────────────────────────────────────────────────────── 几何

float radiusAt(vec2 c, vec4 r) {
  if (c.x >= 0.0) {
    return c.y <= 0.0 ? r.y : r.z;
  }
  return c.y <= 0.0 ? r.x : r.w;
}

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 roundRectGrad(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  vec2 g;
  if (q.x > 0.0 && q.y > 0.0) {
    g = q / max(length(q), 1e-4);
  } else {
    g = (q.x > q.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  }
  return sign(p) * g;
}

// 竖直剖面：t∈[0,1] 映射到五阶平滑的 [-1,1]，端点一二阶导为零
float smooth5Map(float t) {
  t = mix(0.5, 1.0, clamp(t, 0.0, 1.0));
  t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  return (t - 0.5) * 2.0;
}

// 返回 (circle, d(circle)/dx)。x 是带内归一化深度，0 在轮廓、1 在带内边界。
vec2 circleAt(float x) {
  float s = sqrt(clamp(x, 0.0, 1.0));
  float sr = max(s, 1e-2);
  float u = 0.5 + 0.5 * sr;
  return vec2(smooth5Map(s), 15.0 * u * u * (1.0 - u) * (1.0 - u) / sr);
}

// ───────────────────────────────────────────────────────────── 光学

vec3 miRefract(vec3 I, vec3 N, float eta) {
  float d = dot(N, I);
  float k = 1.0 - eta * eta * (1.0 - d * d);
  if (k < 0.0) { return vec3(0.0); }
  return eta * I - (eta * d + sqrt(k)) * N;
}

// 加光：亮处收着、暗处放开，避免整圈过曝
vec3 addLight(vec3 color, vec3 lightColor, float strength) {
  float w = 0.3 + 0.7 * clamp(1.9 - 2.15 * dot(color, kLuma), 0.0, 1.0);
  return color + lightColor * strength * w;
}

float calculateLighting(vec3 normal, vec3 lightDir, float intensity) {
  float d = dot(normal, lightDir);
  float angleFactor = clamp(1.0 - sqrt(max(1.0 - d, 0.0)) * uAngleK, 0.0, 1.0);
  return max(d, 0.0) * intensity * angleFactor;
}

// 对比扩展：围绕 k 缩放，不是叠白。
// tint = 环境光色（归一化，最大通道=1）：提亮朝环境色方向而非纯白，
// 这样轮廓光会带上附近光的色相（暖壁纸→暖黄亮线，绿背景→绿亮线）。
// tint=vec3(1.0) 时退化为纯白打光。
vec4 hsvv(vec4 col, float lighten, vec3 tint) {
  float v = dot(col.rgb, kLuma);
  float w = smoothstep(0.0, 0.5, v);
  float k = mix(1.0 - v, v, w);
  float g = 1.0 + smoothstep(0.0, 1.0, lighten) * mix(0.75, 0.4, w);
  float delta = k * g - k;
  return vec4(col.rgb + delta * tint, col.a);
}

// 亮度越低补光越强；1.0 满补，0.5 半补
float dynamicAdd(vec3 color) {
  return mix(0.5, mix(0.5, 1.0, smoothstep(0.2, 1.0, distance(vec3(1.0), color))),
             dot(color, kLuma));
}

vec4 processLighting(vec4 color, vec3 normal, float x, float falloffEnd,
                     vec3 ambient) {
  // 屏幕 y 向下，光照法线要翻 y 才与"左上打光"的观感一致
  vec3 lightNormal = vec3(normal.x, -normal.y, normal.z);
  float l1 = calculateLighting(lightNormal, uLightDir, uLightIntensity);
  float l2 = calculateLighting(lightNormal, uLightDir * vec3(-1.0, -1.0, 1.0),
                               uLightOpposite);
  float mask = (falloffEnd >= 0.999)
      ? 1.0
      : 1.0 - smoothstep(0.0, max(falloffEnd, 1e-3), x);
  // 强度收敛：原 2.0 过曝，压到 1.1，配合环境色 tint 观感更接近真机
  float lightenParam = (l1 + l2) * 1.1 * dynamicAdd(color.rgb) * mask;
  // 环境光色：取大模糊背景色归一化（保留色相，最大通道=1）
  vec3 tint = ambient / max(max(ambient.r, max(ambient.g, ambient.b)), 0.05);
  return hsvv(color, lightenParam, tint);
}

// ───────────────────────────────────────────────────────────── 调色

// 注意染的是**亮部**：亮处被拉向深紫黑，正是系统大面板"发乌"的来源
vec3 glassDarker(vec3 c) {
  float k = mix(0.0, uDarker, smoothstep(uDarkerRange.x, uDarkerRange.y, dot(c, kLuma)));
  return mix(c, uDarkerColor, k);
}

vec3 glassAdjust(vec3 c, float sat, float bri) {
  float l = dot(c, vec3(0.2125, 0.7153, 0.0721));
  return mix(vec3(l), c, sat) + bri;
}

// gcr 是"玻璃本体的透射率"，恒 ≤ 1；c*gcr 就是压暗的来源。
vec4 processGlassColor(vec3 refractCol, vec3 bigCol) {
  vec3 c = glassDarker(refractCol);
  float l = clamp(dot(c, kLuma), 0.0, 1.0);
  float lc = ((uLuminance.x * l + uLuminance.y) * l + uLuminance.z) * l + uLuminance.w;
  float curve = clamp(lc, 0.0, 1.0) / max(l, 0.01) * smoothstep(0.0, 0.1, l);
  c = c * mix(1.0, curve, uLuminanceAmount);
  c = glassAdjust(c, uSaturation, uBrightness);

  vec3 b = glassDarker(bigCol);
  b = glassAdjust(b, uBgSat, uBgBri);
  b = mix(b, vec3(1.0), uInnerWhite);

  float lumin = clamp(dot(b, kLuma), 0.0, 1.0);
  float tBurn = (uBurn <= 0.0) ? 1.0 : pow(lumin, uBurn);
  tBurn -= 0.5;
  float ratio = 0.8 * mix(lumin, 1.0, 1.587 * tBurn * tBurn * tBurn + 0.5);

  vec3 gcr = mix(vec3(1.0), b, ratio);
  // 中性背景上不做去色，避免整块玻璃灰掉
  float m = (gcr.r + gcr.g + gcr.b) / 3.0;
  float gmask = smoothstep(0.0, 0.4, length(b - vec3(m)));
  gcr = mix(vec3(m), gcr, gmask);
  gcr = mix(gcr, uTint.rgb, uTint.a);

  // 玻璃内部按比例混入 gcr：不是"贴一层膜"，而是"补上玻璃自身的漫射"
  float im = uInnerMix * ratio;
  c = mix(c * gcr, gcr, im);
  return vec4(clamp(c, 0.0, 1.0), 1.0);
}

// 位移上限。官方把 thickness/reflectOffset 按 3x 物理像素给出（100/1000），
// 折成逻辑像素后折射位移可达 54dp、反射 52dp——比一整条壁纸条纹还宽，
// 于是边缘整圈都在"拉远处的颜色"，在高对比背景上糊成一条错色带。
// 真机壁纸是平滑渐变所以看不出来。这里把位移收到倒角带自身尺度（edgePx 的 3 倍），
// 保留"透镜卷边"的手感，但取样永远落在邻域内。
float lensCap() { return uEdgePx * 3.0; }

vec2 clampLens(vec2 off) {
  float cap = lensCap();
  float m = length(off);
  return m > cap ? off * (cap / m) : off;
}

// ───────────────────────────────────────────────────────────── 主体

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = fragCoord - halfSize;
  float cornerR = min(radiusAt(p, uRadii), min(halfSize.x, halfSize.y));
  float sd = sdRoundRect(p, halfSize, cornerR);

  vec4 outColor = vec4(0.0);

  // 轮廓外：SDF 给 0.7px 抗锯齿，其余全透明。
  // 淡出必须窄于边缘亮带，否则轮廓处 alpha→0 会把那条 1px 亮线整个吃掉。
  float sdAlpha = 1.0 - smoothstep(-0.4, 0.0, sd);
  if (sdAlpha > 0.002) {
    float x = clamp(-sd / max(uEdgePx, 1e-3), 0.0, 1.0);
    vec2 cd = circleAt(x);
    float circle = cd.x;
    float a = max(1.0 - circle, 1e-6);

    // w：带内累积的"已倒角程度"；0.85 之后是平台
    float w = (x >= 0.85) ? 1.0 : 1.0 - pow(a, uEdgePow);
    float nmlZ = (x >= 0.85) ? 1.0 : circle;
    bool inner = (1.0 - w) <= 1e-6;

    // 坡度：由剖面导数给出，clamp 64 防止圆角切点处爆掉
    float g = inner ? 0.0 : uEdgePow * ((1.0 - w) / a) * cd.y;
    g = min(g, 64.0);

    float finalAlpha = inner ? 1.0 : smoothstep(0.0, uNmlZAAThreshold, nmlZ);

    vec2 nxy = inner ? vec2(0.0) : roundRectGrad(p, halfSize, cornerR) * g;
    vec3 normal = inner ? vec3(0.0, 0.0, 1.0) : normalize(vec3(nxy, 1.0));

    // ── 折射：带内按 (thickness-edge)*2 → thickness*2 混合厚度
    vec3 refractionCol;
    if (inner) {
      refractionCol = sampleLevel(fragCoord);
    } else {
      vec3 refractDir = miRefract(vec3(0.0, 0.0, -1.0), normal, 1.0 / max(uIOR, 1.0));
      float refractThickness = mix((uThicknessPx - uEdgePx) * 2.0, uThicknessPx * 2.0, w);
      refractThickness *= step(0.5, uThicknessPx);
      refractionCol = sampleLevel(fragCoord + clampLens(refractDir.xy * refractThickness));
    }

    vec3 materialRgb;
    if (inner) {
      materialRgb = refractionCol;
    } else {
      // ── 反射：外棱面把远处背景"卷"进来
      vec2 refractXY = 2.0 * normal.z * normal.xy;
      vec3 reflectionCol = sampleLevel(
        fragCoord + clampLens(refractXY * (uReflectOffsetPx * (1.0 - w)))
      );
      materialRgb = mix(refractionCol, reflectionCol, (1.0 - nmlZ) * uReflStrength);
      materialRgb = addLight(materialRgb, reflectionCol, (1.0 - w) * uReflLighten);
    }

    vec3 bigCol = sampleCoarse(fragCoord);
    vec4 glassMaterial = processGlassColor(materialRgb, bigCol);

    // 底部内发光：玻璃厚度的补偿，越靠下越亮
    float tEdge = smoothstep(0.0, 1.0, fragCoord.y / max(uSize.y, 1.0));
    glassMaterial.rgb += tEdge * tEdge * uInnerBottom;

    if (!inner) {
      // 轮廓打光：方向光（dot(lightNormal, lightDir)）驱动，**不是整圈均匀描边**。
      // 打光色 = bigCol 环境色归一化（暖壁纸→暖黄亮线），不再纯白。
      //
      // 真机（Mi17Pro 通知卡片）实测：水平边（上/下）有连续亮线，垂直边（左/右）
      // 几乎没有——光从上方偏左打来。HSV 对比扩展只把朝光的那侧棱边拉开明暗，
      // 背光侧落回内部亮度，所以四角和四边不会一起亮。
      glassMaterial = processLighting(glassMaterial, normal, x, uLightFalloff, bigCol);
    }

    glassMaterial = pow(glassMaterial, vec4(uColorPow));
    glassMaterial.rgb = mix(clamp(glassMaterial.rgb, 0.0, 1.0), uTint.rgb, uUnshade);
    glassMaterial.a *= uAlpha * finalAlpha * sdAlpha;

    outColor = vec4(glassMaterial.rgb * glassMaterial.a, glassMaterial.a);
  }

  fragColor = outColor;
}
