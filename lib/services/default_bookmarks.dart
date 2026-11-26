import '../models/browser_models.dart';

/// 首次启动预置的快捷访问（书签）。
///
/// 原版 Roam 首次打开首页就有一屏站点，不需要用户先手动加书签。
/// 这里照做：新建一份书签写入存储，之后它们就是普通书签——可以在
/// 「书签管理」里改名、删除，删光后不会被再次补回来（只有存储里
/// 从来没有过书签记录时才预置）。
const _defaults = <(String, String)>[
  ('秘塔AI搜索', 'https://metaso.cn'),
  ('元宝', 'https://yuanbao.tencent.com'),
  ('豆包', 'https://www.doubao.com'),
  ('文心一言', 'https://yiyan.baidu.com'),
  ('千问', 'https://tongyi.aliyun.com'),
  ('百度', 'https://www.baidu.com'),
  ('凤凰网', 'https://www.ifeng.com'),
  ('学习通', 'https://i.chaoxing.com'),
  ('哔哩哔哩', 'https://m.bilibili.com'),
  ('新浪微博', 'https://m.weibo.cn'),
  ('知乎', 'https://www.zhihu.com'),
  ('豆瓣', 'https://www.douban.com'),
  ('爱奇艺', 'https://www.iqiyi.com'),
  ('网易云音乐', 'https://music.163.com'),
  ('Google', 'https://www.google.com'),
];

/// 生成预置书签。`id` 用序号 + 时间戳，保证与后续手动添加的 id 不冲突。
List<Bookmark> defaultBookmarks(DateTime now) {
  return [
    for (var i = 0; i < _defaults.length; i++)
      Bookmark(
        id: 'default_${i}_${now.millisecondsSinceEpoch}',
        title: _defaults[i].$1,
        url: _defaults[i].$2,
        // 让顺序稳定：越靠前的建成时间越早。
        createdAt: now.subtract(Duration(seconds: _defaults.length - i)),
      ),
  ];
}
