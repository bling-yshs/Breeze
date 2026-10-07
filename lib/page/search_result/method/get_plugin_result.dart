import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/jm_web_search.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/page/search_result/models/comic_number.dart';
import 'package:zephyr/page/search_result/models/unified_plugin_search.dart';

/// 按图源获取搜索结果并追加到当前列表。
///
/// [event] 提供关键词、图源和页码，[blocState] 保存已有结果及分页状态。
/// 返回追加结果后的状态，禁漫普通关键词搜索使用网页接口获取点赞数量。
Future<BlocState> getPluginSearchResult(
  SearchEvent event,
  BlocState blocState,
) async {
  final pluginId = event.searchStates.from.trim();
  if (pluginId.isEmpty) {
    throw StateError('search source is empty');
  }
  final extern = Map<String, dynamic>.from(event.searchStates.pluginExtern);
  final keyword = event.searchStates.searchKeyword.trim();
  final directId = RegExp(
    r'^(?:jm\s*)?\d+$',
    caseSensitive: false,
  ).hasMatch(keyword);
  final useJmWeb =
      pluginId == 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9' &&
      !directId &&
      (extern['path']?.toString().trim().isEmpty ?? true);
  final response = useJmWeb
      ? await searchJmWeb(
          pluginId: pluginId,
          keyword: keyword,
          page: event.page,
          extern: extern,
        )
      : await callUnifiedComicPlugin(
          pluginId: pluginId,
          fnPath: 'searchComic',
          core: {'keyword': keyword, 'page': event.page},
          extern: extern,
        );
  final parsed = UnifiedPluginSearchResponse.fromMap(response);

  final list = parsed.items
      .map((item) => _toUnifiedComic(item, event.page, parsed.source))
      .toList();

  blocState.pagesCount = parsed.paging.page;
  blocState.hasReachedMax = parsed.paging.hasReachedMax;
  blocState.comics = [...blocState.comics, ...list];
  blocState.pluginExtern = parsed.extern;
  return blocState;
}

ComicNumber _toUnifiedComic(
  UnifiedPluginSearchItem item,
  int page,
  String source,
) {
  return ComicNumber(
    buildNumber: page,
    comic: unifiedComicFromPluginSearchItem(item, source),
  );
}
