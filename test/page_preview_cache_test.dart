import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/services/page_preview_cache.dart';

PagePreview _page(String url) => PagePreview(
  url: url,
  bytes: Uint8List.fromList([1, 2, 3]),
  aspectRatio: 0.5,
);

void main() {
  final cache = PagePreviewCache.instance;

  setUp(cache.clear);

  test('首张快照不产生上一页', () {
    cache.record('t', _page('https://a.com'));
    expect(cache.previous('t'), isNull);
    expect(cache.currentOf('t')?.url, 'https://a.com');
  });

  test('导航一开始就把当前页压栈，不等新页加载完成', () {
    cache.record('t', _page('https://a.com'));
    cache.beginNavigation('t');
    expect(cache.previous('t')?.url, 'https://a.com');

    // 新页还没加载完，上一页已经可用
    cache.record('t', _page('https://b.com'));
    expect(cache.previous('t')?.url, 'https://a.com');
    expect(cache.currentOf('t')?.url, 'https://b.com');
  });

  test('后退不再把刚离开的页压栈', () {
    cache.record('t', _page('https://a.com'));
    cache.beginNavigation('t');
    cache.record('t', _page('https://b.com'));

    // 用户侧滑/点返回：先消费，再触发后退导航
    cache.consumeBack('t');
    cache.beginNavigation('t');
    cache.record('t', _page('https://a.com'));

    expect(cache.previous('t'), isNull, reason: '回到 A 之后没有更早的页');
    expect(cache.currentOf('t')?.url, 'https://a.com');
  });

  test('多级历史按顺序出栈', () {
    cache.record('t', _page('https://a.com'));
    cache.beginNavigation('t');
    cache.record('t', _page('https://b.com'));
    cache.beginNavigation('t');
    cache.record('t', _page('https://c.com'));

    expect(cache.previous('t')?.url, 'https://b.com');
    cache.consumeBack('t');
    expect(cache.previous('t')?.url, 'https://a.com');
  });

  test('单页应用改 URL 也能补上上一页', () {
    cache.record('t', _page('https://a.com/1'));
    // 不走 onPageStarted，直接加载完成
    cache.record('t', _page('https://a.com/2'));
    expect(cache.previous('t')?.url, 'https://a.com/1');
  });

  test('同一页重复记录不重复压栈', () {
    cache.record('t', _page('https://a.com'));
    cache.beginNavigation('t');
    cache.record('t', _page('https://a.com'));
    cache.record('t', _page('https://b.com'));
    expect(cache.previous('t')?.url, 'https://a.com');
    cache.consumeBack('t');
    expect(cache.previous('t'), isNull);
  });

  test('快照更新会通知界面（否则背景刷新不及时）', () {
    var notified = 0;
    void listener() => notified++;
    cache.addListener(listener);
    cache.record('t', _page('https://a.com'));
    expect(notified, 1);
    cache.beginNavigation('t');
    expect(notified, 2);
    cache.removeListener(listener);
  });
}
