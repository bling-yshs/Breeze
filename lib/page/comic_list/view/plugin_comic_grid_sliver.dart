import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search_result/widgets/bottom_loader.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_grid.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/enum.dart';

class PluginComicGridSliver extends StatelessWidget {
  /// 创建具有分页加载状态的漫画网格。
  ///
  /// [entries] 提供卡片数据，[likesCounts] 按漫画 ID 提供点赞数量，
  /// [type]、[refresh]、[onDeleteSuccess] 配置卡片操作。
  /// [hasReachedMax]、[isLoadingMore]、[loadMoreFailed] 描述分页状态，
  /// [onRetryLoadMore]、[onLoadMore] 处理加载请求。
  /// [controller]、[physics]、[shrinkWrap] 配置滚动，
  /// [onEntryTap]、[onEntryLongPress]、[onEntrySecondaryTapDown] 处理交互，
  /// [isEntrySelected]、[selectionMode] 配置选择状态，
  /// [collectionTargetId]、[collectionTargetName] 指定收藏目标，[key] 标识组件。
  /// 返回漫画网格组件。
  const PluginComicGridSliver({
    super.key,
    required this.entries,
    this.likesCounts = const {},
    this.type = ComicEntryType.normal,
    this.refresh,
    this.onDeleteSuccess,
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.onRetryLoadMore,
    required this.onLoadMore,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.onEntryTap,
    this.onEntryLongPress,
    this.onEntrySecondaryTapDown,
    this.isEntrySelected,
    this.selectionMode = false,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  final List<ComicSimplifyEntryInfo> entries;
  final Map<String, int> likesCounts;
  final ComicEntryType type;
  final VoidCallback? refresh;
  final ValueChanged<String>? onDeleteSuccess;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ValueChanged<ComicSimplifyEntryInfo>? onEntryTap;
  final void Function(
    ComicSimplifyEntryInfo info,
    LongPressStartDetails details,
  )?
  onEntryLongPress;
  final void Function(ComicSimplifyEntryInfo info, TapDownDetails details)?
  onEntrySecondaryTapDown;
  final bool Function(ComicSimplifyEntryInfo entry)? isEntrySelected;
  final bool selectionMode;
  final String? collectionTargetId;
  final String? collectionTargetName;

  /// 使用 [context] 构建漫画卡片及分页操作，返回可滚动的网格。
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: [
        BaseComicGridSliver(
          entries: entries,
          likesCounts: likesCounts,
          type: type,
          refresh: refresh,
          onDeleteSuccess: onDeleteSuccess,
          onEntryTap: onEntryTap,
          onEntryLongPress: onEntryLongPress,
          onEntrySecondaryTapDown: onEntrySecondaryTapDown,
          isEntrySelected: isEntrySelected,
          selectionMode: selectionMode,
          collectionTargetId: collectionTargetId,
          collectionTargetName: collectionTargetName,
        ),
        if (hasReachedMax)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Text(
                  t.oldHome.noMore,
                  style: const TextStyle(fontSize: 20.0),
                ),
              ),
            ),
          ),
        if (isLoadingMore)
          const SliverToBoxAdapter(child: Center(child: BottomLoader())),
        if (loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: onRetryLoadMore,
                    child: Text(t.oldHome.loadMoreFailed),
                  ),
                ],
              ),
            ),
          ),
        if (!hasReachedMax && !isLoadingMore && !loadMoreFailed)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 6),
                child: TextButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  label: Text(t.oldHome.loadMore),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
