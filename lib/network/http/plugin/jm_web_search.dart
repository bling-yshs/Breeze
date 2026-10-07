import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:zephyr/network/http/plugin/jm_web_search_browser.dart';
import 'package:zephyr/network/http/wind_http.dart';

/// 从禁漫网页搜索结果提取漫画、点赞数量及分页信息。
///
/// [pluginId] 用于关联图源，[keyword] 保留网页支持的包含和排除语法，
/// [page] 为从 1 开始的页码，[extern] 携带排序、时间和搜索类型参数。
/// 支持 WebView 的平台使用浏览器会话处理网站验证。
/// 返回符合统一插件搜索协议的数据；请求或页面解析失败时抛出异常。
Future<Map<String, dynamic>> searchJmWeb({
  required String pluginId,
  required String keyword,
  required int page,
  required Map<String, dynamic> extern,
}) async {
  final sortBy = int.tryParse(extern['sortBy']?.toString() ?? '') ?? 1;
  final order = extern['sort']?.toString().trim();
  final searchUri = Uri.https('18comic.vip', '/search/photos', {
    'main_tag': (extern['main_tag'] ?? 0).toString(),
    'search_query': keyword.trim(),
    'page': page.toString(),
    'o': (order?.isNotEmpty ?? false)
        ? order!
        : switch (sortBy) {
            2 => 'mv',
            3 => 'mp',
            4 => 'tf',
            _ => 'mr',
          },
    't': (extern['t'] ?? 'a').toString(),
  });
  final String html;
  final Uri baseUri;
  if (Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows) {
    final browserPage = await loadJmSearchWebPage(searchUri);
    html = browserPage.html;
    baseUri = browserPage.uri;
  } else {
    final response = await fetch(
      searchUri.toString(),
      headers: {'Accept': 'text/html', 'Referer': 'https://18comic.vip/'},
    );
    if (!response.ok) {
      final challenge = response.header('cf-mitigated') == 'challenge';
      throw StateError(
        challenge
            ? '禁漫网站需要浏览器验证，当前平台暂未接入验证窗口'
            : '禁漫网页搜索请求失败：HTTP ${response.status}',
      );
    }
    html = response.text;
    baseUri = Uri.parse(response.url);
  }

  final document = html_parser.parse(html);
  final summary = document.querySelector('.well-sm');
  final totalText = document.querySelector('.search-pagination-total')?.text;
  final totalMatch = RegExp(r'共\s*([\d,]+)\s*部').firstMatch(totalText ?? '');
  final summaryMatch = RegExp(
    r'([\d,]+)\s*搜索結果',
  ).firstMatch(summary?.text ?? '');
  final total = int.tryParse(
    (totalMatch?.group(1) ?? summaryMatch?.group(1) ?? '').replaceAll(',', ''),
  );
  if (total == null) {
    throw const FormatException('禁漫网页搜索返回了无法识别的页面，请检查网页访问状态');
  }

  final items = <Map<String, dynamic>>[];
  final seenIds = <String>{};
  for (final card in document.querySelectorAll('.list-col')) {
    final link = card.querySelector('.thumb-overlay a[href^="/album/"]');
    final id = RegExp(
      r'^/album/(\d+)(?:/|$)',
    ).firstMatch(link?.attributes['href'] ?? '')?.group(1);
    if (id == null || !seenIds.add(id)) {
      continue;
    }
    final image = link?.querySelector('img');
    final title =
        (card.querySelector('.video-title')?.text ??
                image?.attributes['title'] ??
                image?.attributes['alt'] ??
                '')
        .trim();
    final cover =
        (image?.attributes['data-original'] ?? image?.attributes['src'] ?? '')
        .trim();
    if (title.isEmpty || cover.isEmpty) {
      throw const FormatException('禁漫网页搜索结果缺少标题或封面');
    }
    final likesText = (card.querySelector('.label-loveicon span')?.text ?? '')
        .trim()
        .replaceAll(',', '');
    final likesMatch = RegExp(
      r'^(\d+(?:\.\d+)?)\s*([KkMm万萬亿億]?)$',
    ).firstMatch(likesText);
    if (likesMatch == null) {
      throw const FormatException('禁漫网页搜索结果缺少有效点赞数量');
    }
    final multiplier = switch (likesMatch.group(2)?.toUpperCase()) {
      'K' => 1000,
      'M' => 1000000,
      '万' || '萬' => 10000,
      '亿' || '億' => 100000000,
      _ => 1,
    };
    final likes = (double.parse(likesMatch.group(1)!) * multiplier).round();
    final authors = card
        .querySelectorAll('a[href*="main_tag=2"]')
        .map((element) => element.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final categories = card
        .querySelectorAll('.label-category, .label-sub')
        .map((element) => element.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final tags = card
        .querySelectorAll('.tags a')
        .map((element) => element.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final coverUrl = baseUri.resolve(cover).toString();
    items.add({
      'source': pluginId,
      'id': id,
      'title': title,
      'subtitle': '',
      'finished': false,
      'likesCount': likes,
      'viewsCount': 0,
      'updatedAt': '',
      'cover': {
        'id': id,
        'url': coverUrl,
        'path': '$id.jpg',
        'extern': {'path': '$id.jpg'},
      },
      'metadata': [
        if (authors.isNotEmpty)
          {'type': 'author', 'name': '作者', 'value': authors},
        if (categories.isNotEmpty)
          {'type': 'categories', 'name': '分类', 'value': categories},
        if (tags.isNotEmpty)
          {'type': 'tags', 'name': '标签', 'value': tags},
      ],
      'raw': {
        'id': id,
        'name': title,
        'author': authors.join('/'),
        'image': coverUrl,
        'likes': likes,
        'likesText': likesText,
        'tags': tags,
      },
      'extern': <String, dynamic>{},
    });
  }
  if (total > 0 && items.isEmpty) {
    throw const FormatException('禁漫网页搜索结果解析失败');
  }
  final pages = total == 0 ? 1 : (total / 80).ceil();
  return {
    'source': pluginId,
    'extern': {...extern, 'sortBy': sortBy},
    'data': {
      'paging': {
        'page': page,
        'pages': pages,
        'total': total,
        'hasReachedMax': total == 0 || page >= pages,
      },
      'items': items,
    },
  };
}
