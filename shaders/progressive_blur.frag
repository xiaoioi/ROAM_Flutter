#version 460 core
#include <flutter/runtime_effect.glsl>

// ─────────────────────────────────────────────────────────────────────────────
// progressiveTextureBlur · miuix 原版移植
//
// 对齐 compose-miuix-ui/miuix · miuix-blur 的
// `createProgressiveBlurEffect` / `progressiveBlurShaderForTap`：
//
//   raw    = clamp(dot(q, gradVec) + gradOffset, 0, 1)
//   smooth = curve <= 0 ? raw : pow(raw, curve)
//   radius = maxRadius * (1 - smooth)        ← 半径沿方向连续衰减到 0
//   sigma  = radius * .5 + .5                ← 与原版一致
//
// 原版在 Android 上用两个 RenderEffect pass（H / V）做可分离卷积；Flutter 的
// FragmentShader 只能单 pass，这里用二维螺旋采样近似同一核，采样落在 Dart 侧
// 已降采样的纹理上（半径按 sigma 取 1×/2×/4×/8×）。
//
// radius 逐像素计算，不是多张不同半径的图叠加：过渡是真正连续的
// 「中等模糊 → 清晰」，没有台阶，也没有多档混合的重影。
// ─────────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;        // 组件逻辑尺寸
uniform vec2 uTexSize;     // 纹理像素尺寸
uniform vec2 uOrigin;      // 组件左上角在纹理中的像素坐标（可为负）
uniform float uMaxRadius;  // 满强度半径（逻辑 px）
uniform vec2 uGradVec;     // 归一化梯度向量（已含 1/span）
uniform float uGradOffset;
uniform float uCurve;      // 0 = 线性；>0 = pow(raw, curve)
uniform float uScale;      // 逻辑 px → 纹理 px 的比例
uniform sampler2D uTex;

out vec4 fragColor;

const int kTaps = 40;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = (p * uScale + uOrigin) / uTexSize;

  vec2 q = p / uSize;
  float raw = clamp(dot(q, uGradVec) + uGradOffset, 0.0, 1.0);
  float smoothRaw = uCurve <= 0.0 ? raw : pow(raw, uCurve);

  float radius = uMaxRadius * (1.0 - smoothRaw) * uScale;
  vec4 center = texture(uTex, uv);
  if (radius < 0.6) {
    fragColor = center;
    return;
  }

  float sigma = radius * 0.5 + 0.5;
  float inv2s2 = 1.0 / (2.0 * sigma * sigma);

  // 螺旋采样：r 按 sqrt 分布（面积均匀），角度黄金角错开，避免网格伪影。
  vec4 sum = center;
  float wsum = 1.0;
  for (int i = 0; i < kTaps; i++) {
    float fi = float(i) + 0.5;
    float r = sqrt(fi / float(kTaps)) * radius * 1.15;
    float a = fi * 2.39996323;
    vec2 o = vec2(cos(a), sin(a)) * r;
    float w = exp(-r * r * inv2s2);
    sum += texture(uTex, uv + o / uTexSize) * w;
    wsum += w;
  }
  fragColor = sum / wsum;
}
