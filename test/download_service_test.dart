import 'package:flutter_test/flutter_test.dart';
import 'package:roam_flutter/models/browser_models.dart';
import 'package:roam_flutter/services/download_service.dart';

void main() {
  group('DownloadService.suggestedFileName', () {
    test('优先使用 Content-Disposition 的文件名', () {
      expect(
        DownloadService.suggestedFileName(
          'https://example.com/download?id=1',
          'attachment; filename="report.pdf"',
          'application/pdf',
        ),
        'report.pdf',
      );
    });

    test('支持 RFC 5987 编码文件名', () {
      expect(
        DownloadService.suggestedFileName(
          'https://example.com/file',
          "attachment; filename*=UTF-8''%E6%98%9F%E7%8E%AF.apk",
          'application/vnd.android.package-archive',
        ),
        '星环.apk',
      );
    });

    test('没有响应头时退回 URL 末段', () {
      expect(
        DownloadService.suggestedFileName(
          'https://example.com/a/b/setup.exe?token=1',
          null,
          null,
        ),
        'setup.exe',
      );
    });

    test('非法字符被替换', () {
      final name = DownloadService.sanitizeFileName('a/b:c*?.zip');
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
      expect(name.endsWith('.zip'), isTrue);
    });
  });

  group('DownloadEntry', () {
    test('进行中的任务在重启后标记为失败', () {
      final entry = DownloadEntry(
        id: 'dl_1',
        fileName: 'a.apk',
        url: 'https://example.com/a.apk',
        path: '/tmp/a.apk',
        mimeType: 'application/vnd.android.package-archive',
        createdAt: DateTime(2026, 11, 14),
      );
      final restored = DownloadEntry.fromJson(entry.toJson());
      expect(restored.status, DownloadStatus.failed);
    });
  });
}
