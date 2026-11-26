import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/models/browser_models.dart';
import 'package:roam_flutter/services/url_resolver.dart';

void main() {
  const resolver = UrlResolver();
  const settings = BrowserSettings();

  group('UrlResolver', () {
    test('裸域名补全为 https', () {
      final result = resolver.resolve('example.com', settings);
      expect(result.kind, AddressKind.web);
      expect(result.uri.toString(), 'https://example.com');
    });

    test('完整地址保持协议', () {
      final result = resolver.resolve('http://example.com/a?b=1', settings);
      expect(result.uri.toString(), 'http://example.com/a?b=1');
    });

    test('带端口与路径的域名', () {
      final result = resolver.resolve('localhost:8080/admin', settings);
      expect(result.kind, AddressKind.web);
      expect(result.uri.toString(), 'https://localhost:8080/admin');
    });

    test('普通词组交给搜索引擎', () {
      final result = resolver.resolve('星环 浏览器', settings);
      expect(result.kind, AddressKind.web);
      expect(result.uri.toString(), contains('bing.com/search'));
      expect(result.uri.toString(), contains('%E6%98%9F%E7%8E%AF'));
    });

    test('自定义模板替换关键词', () {
      final result = resolver.resolve(
        'flutter 液态玻璃',
        const BrowserSettings(
          searchEngine: SearchEngine.custom,
          customSearchTemplate: 'https://duckduckgo.com/?q=%s',
        ),
      );
      expect(result.uri!.host, 'duckduckgo.com');
      expect(result.uri!.queryParameters['q'], 'flutter 液态玻璃');
    });

    test('已知外部协议交给系统', () {
      expect(
        resolver.resolve('mailto:hi@roam.app', settings).kind,
        AddressKind.external,
      );
      expect(
        resolver.resolve('tel:10086', settings).kind,
        AddressKind.external,
      );
    });

    test('空输入回到起始页', () {
      expect(resolver.resolve('   ', settings).kind, AddressKind.home);
    });

    test('shortUrl 去掉 www 与根路径', () {
      expect(UrlResolver.shortUrl('https://www.bilibili.com/'), 'bilibili.com');
      expect(
        UrlResolver.shortUrl('https://github.com/morluto/rea'),
        'github.com/morluto/rea',
      );
    });
  });

  group('BrowserSettings', () {
    test('JSON 往返保持字段', () {
      const source = BrowserSettings(
        searchEngine: SearchEngine.google,
        themeMode: AppThemeMode.dark,
        javascriptEnabled: false,
        desktopMode: true,
        restoreTabs: false,
      );
      final restored = BrowserSettings.fromJson(source.toJson());
      expect(restored.searchEngine, SearchEngine.google);
      expect(restored.themeMode, AppThemeMode.dark);
      expect(restored.javascriptEnabled, isFalse);
      expect(restored.desktopMode, isTrue);
      expect(restored.restoreTabs, isFalse);
    });

    test('未知枚举回退到默认值', () {
      final restored = BrowserSettings.fromJson(const {
        'searchEngine': 'unknown',
        'themeMode': 'neon',
      });
      expect(restored.searchEngine, SearchEngine.bing);
      expect(restored.themeMode, AppThemeMode.system);
    });
  });
}
