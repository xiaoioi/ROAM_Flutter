import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/browser_models.dart';

class BrowserStore {
  BrowserStore(this._preferences);

  static const _settingsKey = 'roam.settings.v1';
  static const _bookmarksKey = 'roam.bookmarks.v1';
  static const _historyKey = 'roam.history.v1';
  static const _tabsKey = 'roam.tabs.v1';
  static const _activeTabKey = 'roam.active_tab.v1';
  static const _downloadsKey = 'roam.downloads.v1';
  static const _seededKey = 'roam.defaults_seeded.v1';

  final SharedPreferences _preferences;

  /// 预置的快捷访问（书签）是否已经写过一次。
  ///
  /// 用它而不是「书签列表是否为空」来判断：用户把预置书签全删掉之后
  /// 不应该被重新塞回来。
  bool get defaultsSeeded => _preferences.getBool(_seededKey) ?? false;

  Future<void> markDefaultsSeeded() => _preferences.setBool(_seededKey, true);

  BrowserSettings loadSettings() {
    final json = _readMap(_settingsKey);
    return json == null
        ? const BrowserSettings()
        : BrowserSettings.fromJson(json);
  }

  Future<void> saveSettings(BrowserSettings settings) {
    return _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<Bookmark> loadBookmarks() =>
      _readList(_bookmarksKey)
          .map(Bookmark.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList();

  Future<void> saveBookmarks(List<Bookmark> bookmarks) => _writeList(
    _bookmarksKey,
    bookmarks.map((item) => item.toJson()).toList(),
  );

  List<HistoryEntry> loadHistory() =>
      _readList(_historyKey)
          .map(HistoryEntry.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList();

  Future<void> saveHistory(List<HistoryEntry> history) =>
      _writeList(_historyKey, history.map((item) => item.toJson()).toList());

  List<BrowserTab> loadTabs() =>
      _readList(_tabsKey)
          .map(BrowserTab.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();

  Future<void> saveTabs(List<BrowserTab> tabs, String activeTabId) async {
    await _writeList(_tabsKey, tabs.map((item) => item.toJson()).toList());
    await _preferences.setString(_activeTabKey, activeTabId);
  }

  String? loadActiveTabId() => _preferences.getString(_activeTabKey);

  Future<void> clearTabs() async {
    await _preferences.remove(_tabsKey);
    await _preferences.remove(_activeTabKey);
  }

  List<DownloadEntry> loadDownloads() =>
      _readList(_downloadsKey).map(DownloadEntry.fromJson).toList();

  Future<void> saveDownloads(List<DownloadEntry> downloads) => _writeList(
    _downloadsKey,
    downloads.map((item) => item.toJson()).toList(),
  );

  Map<String, Object?>? _readMap(String key) {
    try {
      final raw = _preferences.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?>
          ? decoded
          : Map<String, Object?>.from(decoded as Map);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  List<Map<String, Object?>> _readList(String key) {
    try {
      final raw = _preferences.getString(key);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, Object?>> value) {
    return _preferences.setString(key, jsonEncode(value));
  }
}
