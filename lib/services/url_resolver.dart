import '../models/browser_models.dart';

enum AddressKind { home, web, external }

class ResolvedAddress {
  const ResolvedAddress(this.kind, this.uri);

  final AddressKind kind;
  final Uri? uri;
}

class UrlResolver {
  const UrlResolver();

  static final RegExp _domain = RegExp(
    r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(?::\d{1,5})?(?:[/?#].*)?$',
  );
  static final RegExp _ipv4 = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)(?::\d{1,5})?(?:[/?#].*)?$',
  );

  ResolvedAddress resolve(String input, BrowserSettings settings) {
    final value = input.trim();
    if (value.isEmpty) {
      return const ResolvedAddress(AddressKind.home, null);
    }

    final explicit = Uri.tryParse(value);
    if (explicit != null && explicit.hasScheme) {
      if (_isWebUri(explicit)) {
        return ResolvedAddress(AddressKind.web, explicit);
      }
      if (_isAppScheme(explicit, value)) {
        return ResolvedAddress(AddressKind.external, explicit);
      }
    }

    final looksLocal =
        value == 'localhost' ||
        value.startsWith('localhost:') ||
        value.startsWith('localhost/') ||
        value.startsWith('127.') ||
        value.startsWith('[::1]');
    if (_domain.hasMatch(value) || _ipv4.hasMatch(value) || looksLocal) {
      final uri = Uri.parse('https://$value');
      if (_isWebUri(uri)) {
        return ResolvedAddress(AddressKind.web, uri);
      }
    }

    final query = settings.searchEngine.searchUrl(
      value,
      settings.customSearchTemplate,
    );
    return ResolvedAddress(AddressKind.web, Uri.parse(query));
  }

  static bool isWebUri(Uri uri) => _isWebUri(uri);

  static bool _isWebUri(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// 不能交给系统「外部应用」的协议：这些要么由 WebView 自己处理，
  /// 要么本身就是地址输入，剩下的 `xxx://` 一律当外部协议。
  static const _internalSchemes = {
    'http',
    'https',
    'about',
    'data',
    'blob',
    'javascript',
    'file',
    'chrome',
    'content',
  };

  /// 电话、邮件、应用市场，以及微信 / 支付宝 / 淘宝等常见客户端协议。
  static const _appSchemes = {
    'mailto',
    'tel',
    'sms',
    'smsto',
    'geo',
    'market',
    'intent',
    'weixin',
    'wechat',
    'alipays',
    'alipay',
    'taobao',
    'tmall',
    'tbopen',
    'openapp.jdmobile',
    'bilibili',
    'snssdk1128',
    'sinaweibo',
    'zhihu',
    'xhsdiscover',
    'kwai',
    'pinduoduo',
    'youku',
    'iqiyi',
    'qqmusic',
    'orpheus',
    'neteasecloudmusic',
    'spotify',
    'whatsapp',
    'tg',
    'instagram',
    'fb',
    'twitter',
    'youtube',
  };

  /// 已知协议 + 任意「看起来像客户端协议」的 scheme。
  ///
  /// 判断标准：非内部协议；已知协议直接放行；其余必须写成 `xxx://…`，
  /// 避免把 `foo:bar` 这种随手输入当成协议去拉起应用。
  static bool _isAppScheme(Uri uri, String raw) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty || _internalSchemes.contains(scheme)) return false;
    if (_appSchemes.contains(scheme)) return true;
    return raw.contains('://') && scheme.length > 2;
  }

  static String shortUrl(String value) {
    if (value.isEmpty) return '搜索或输入网址';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    return uri.path == '/' || uri.path.isEmpty ? host : '$host${uri.path}';
  }
}
