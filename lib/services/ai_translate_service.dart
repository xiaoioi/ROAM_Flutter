// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// OpenAI 兼容的 AI 翻译客户端。
///
/// 默认目标是哔哩哔哩 Index-Translate 的免费公网接口
/// （`https://index-translate.bilibili.com/v1`，OpenAI 规范，免 key）。
/// 用户也可以在设置里换成任意 OpenAI 兼容服务：接口地址填到 `/v1` 即可，
/// 实际请求 `<base>/chat/completions`。
///
/// 不引第三方 http 包，直接用 `dart:io` 的 HttpClient——这里只有一个
/// JSON POST，没必要为它加依赖。
class AiTranslateService {
  const AiTranslateService();

  /// 单次请求超时。翻译是交互操作，等太久不如报错让用户重试。
  static const Duration _timeout = Duration(seconds: 60);

  Future<TranslateResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String base,
    required String apiKey,
    required String model,
    String? instruction,
  }) async {
    final content = text.trim();
    if (content.isEmpty) {
      throw const TranslateException('没有需要翻译的内容');
    }
    final endpoint = _endpointOf(base);
    final prompt = buildPrompt(
      text: content,
      sourceLang: sourceLang,
      targetLang: targetLang,
      instruction: instruction,
    );

    final isBilibili = endpoint.host.contains('bilibili.com');
    final body = <String, Object?>{
      'model': model,
      'stream': false,
      'temperature': 0.0,
      'max_tokens': (content.length * 3).clamp(512, 8192),
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      // Index-Translate 是推理型模型，关掉思考链避免把 reasoning 带进译文。
      // 其他服务不认这个字段，只在 B 站接口上带。
      if (isBilibili) 'chat_template_kwargs': {'enable_thinking': false},
    };

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final started = DateTime.now();
    try {
      final request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // 哔哩哔哩的网关会拦截非浏览器 UA（Dart 默认 UA 直接返 412），
      // 这里统一带一个移动端浏览器 UA，顺带兼容多数自建网关。
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36 Roam/1.0',
      );
      final key = apiKey.trim();
      if (key.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      }
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close().timeout(_timeout);
      final raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TranslateException(_errorOf(raw, response.statusCode));
      }
      final decoded = jsonDecode(raw);
      final result = _contentOf(decoded);
      if (result.trim().isEmpty) {
        throw const TranslateException('服务返回了空译文，请重试');
      }
      return TranslateResult(
        text: result.trim(),
        model: (decoded is Map ? decoded['model'] as String? : null) ?? model,
        elapsed: DateTime.now().difference(started),
      );
    } on TimeoutException {
      throw const TranslateException('请求超时，请检查网络或稍后重试');
    } on SocketException catch (e) {
      throw TranslateException('连不上翻译服务：${e.message}');
    } on HandshakeException {
      throw const TranslateException('TLS 握手失败，请检查接口地址');
    } on FormatException {
      throw const TranslateException('服务返回的不是合法 JSON');
    } finally {
      client.close(force: true);
    }
  }

  /// base 可以是 `https://host/v1`、`https://host/v1/`、
  /// 甚至已经写全的 `https://host/v1/chat/completions`。
  static Uri _endpointOf(String base) {
    var value = base.trim();
    if (value.isEmpty) {
      throw const TranslateException('接口地址为空，请先在 AI 设置里填写');
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/chat/completions')) {
      value = '$value/chat/completions';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      throw const TranslateException('接口地址格式不正确');
    }
    return uri;
  }

  static String _errorOf(String raw, int status) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return '翻译失败（$status）：${error['message']}';
        }
        if (error is String) return '翻译失败（$status）：$error';
        if (decoded['message'] is String) {
          return '翻译失败（$status）：${decoded['message']}';
        }
      }
    } catch (_) {
      // 非 JSON 错误体，落到下面的通用文案
    }
    final brief = raw.trim();
    final tail = brief.length > 160 ? '${brief.substring(0, 160)}…' : brief;
    return '翻译失败（HTTP $status）${tail.isEmpty ? '' : '：$tail'}';
  }

  static String _contentOf(Object? decoded) {
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is String) return content;
      if (content is List) {
        // 部分服务把 content 拆成分段对象（多模态返回格式）。
        final buffer = StringBuffer();
        for (final part in content) {
          if (part is Map && part['text'] is String) {
            buffer.write(part['text']);
          }
        }
        return buffer.toString();
      }
    }
    final text = first['text'];
    return text is String ? text : '';
  }

  /// 严格对齐 Index-Translate 官方演示页的 instTrans 提示结构：
  /// 指定源/目标语言 + 【源文】+ 【约束要求】+ 只输出译文。
  /// 普通 OpenAI 模型也能读懂这套指令，只是不保证语气像专用翻译模型。
  static String buildPrompt({
    required String text,
    required String sourceLang,
    required String targetLang,
    String? instruction,
  }) {
    final target = targetLang.trim().isEmpty ? '简体中文' : targetLang.trim();
    final source = sourceLang.trim();
    final hasSource = source.isNotEmpty && source != 'auto';
    final header = hasSource ? '请将以下$source文本翻译为$target。' : '请将以下文本翻译为$target。';
    final ins = (instruction ?? '').trim();
    if (ins.isEmpty) {
      return '$header\n\n【源文】\n$text\n\n'
          '【约束要求】\n1. 【指令要求】保持原文格式与分段，术语前后一致。\n\n'
          '只输出译文，不要有任何额外说明。';
    }
    final replaced = ins.replaceAll('目标语言', target);
    return '$header\n\n【源文】\n$text\n\n'
        '【约束要求】\n1. 【指令要求】$replaced\n\n'
        '只输出译文，不要有任何额外说明。';
  }
}

class TranslateResult {
  const TranslateResult({
    required this.text,
    required this.model,
    required this.elapsed,
  });

  final String text;
  final String model;
  final Duration elapsed;
}

class TranslateException implements Exception {
  const TranslateException(this.message);

  final String message;

  @override
  String toString() => message;
}
