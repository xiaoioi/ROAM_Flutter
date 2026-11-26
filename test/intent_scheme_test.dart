import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/models/browser_models.dart';
import 'package:roam_flutter/services/system_bridge.dart';
import 'package:roam_flutter/services/url_resolver.dart';

void main() {
  group('AndroidIntent', () {
    test('拆出 scheme 与 browser_fallback_url', () {
      final intent = AndroidIntent.tryParse(
        'intent://details?id=com.taobao.taobao#Intent;'
        'scheme=taobao;package=com.taobao.taobao;'
        'S.browser_fallback_url=https%3A%2F%2Fm.taobao.com;end',
      );
      expect(intent, isNotNull);
      expect(intent!.targetUrl, 'taobao://details?id=com.taobao.taobao');
      expect(intent.fallbackUrl, 'https://m.taobao.com');
    });

    test('非 intent 链接原样返回 null', () {
      expect(AndroidIntent.tryParse('https://example.com'), isNull);
      expect(AndroidIntent.tryParse('weixin://dl/chat'), isNull);
    });

    test('缺少 scheme 时放弃解析', () {
      expect(AndroidIntent.tryParse('intent://scan/#Intent;end'), isNull);
    });
  });

  group('UrlResolver 外部协议', () {
    const resolver = UrlResolver();
    const settings = BrowserSettings();

    test('微信 / 支付宝这类客户端协议走外部', () {
      expect(
        resolver.resolve('weixin://dl/business/?t=abc', settings).kind,
        AddressKind.external,
      );
      expect(
        resolver.resolve('alipays://platformapi/startapp?appId=1', settings).kind,
        AddressKind.external,
      );
      expect(
        resolver.resolve('bilibili://video/123', settings).kind,
        AddressKind.external,
      );
    });

    test('未列举但带 :// 的协议也交给系统', () {
      expect(
        resolver.resolve('someapp://open?id=1', settings).kind,
        AddressKind.external,
      );
    });

    test('随手输入的 foo:bar 不会被当成协议', () {
      expect(
        resolver.resolve('foo:bar', settings).kind,
        AddressKind.web,
      );
    });

    test('tel:/mailto: 仍然走外部', () {
      expect(
        resolver.resolve('tel:10086', settings).kind,
        AddressKind.external,
      );
      expect(
        resolver.resolve('mailto:a@b.com', settings).kind,
        AddressKind.external,
      );
    });
  });
}
