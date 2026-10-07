import 'package:material_ui/material_ui.dart';
import 'package:zephyr/util/debouncer.dart';

import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/i18n/strings.g.dart';

SliverGridDelegate buildComicSimplifyEntryGridDelegate({
  double mainAxisSpacing = 15,
  double crossAxisSpacing = 15,
  double childAspectRatio = 0.75,
}) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: isTabletWithOutContext() ? 200.0 : 150.0,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: childAspectRatio,
  );
}

class BaseComicGridSliver extends StatelessWidget {
  final List<ComicSimplifyEntryInfo> entries;
  final Map<String, int> likesCounts;
  final ComicEntryType type;
  final VoidCallback? refresh;
  final ValueChanged<String>? onDeleteSuccess;
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
  final bool roundedCorner;
  final EdgeInsetsGeometry padding;
  final String? collectionTargetId;
  final String? collectionTargetName;

  /// 创建漫画卡片网格，可按 ID 在封面上展示 [likesCounts] 中的点赞数量。
  ///
  /// [entries] 提供卡片数据，[type] 指定卡片用途，
  /// [refresh]、[onDeleteSuccess] 处理刷新和删除，
  /// [onEntryTap]、[onEntryLongPress]、[onEntrySecondaryTapDown] 处理交互。
  /// [isEntrySelected]、[selectionMode] 配置选择状态，
  /// [roundedCorner]、[padding] 配置外观，
  /// [collectionTargetId]、[collectionTargetName] 指定收藏目标，[key] 标识组件。
  /// 返回漫画网格组件。
  const BaseComicGridSliver({
    super.key,
    required this.entries,
    this.likesCounts = const {},
    required this.type,
    this.refresh,
    this.onDeleteSuccess,
    this.onEntryTap,
    this.onEntryLongPress,
    this.onEntrySecondaryTapDown,
    this.isEntrySelected,
    this.selectionMode = false,
    this.roundedCorner = true,
    this.padding = const EdgeInsets.all(10),
    this.collectionTargetId,
    this.collectionTargetName,
  });

  /// 使用 [context] 构建带有点赞标记的漫画网格，返回 Sliver 组件。
  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: buildComicSimplifyEntryGridDelegate(),
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = ComicSimplifyEntry(
            key: ValueKey(entries[index].id),
            info: entries[index],
            type: type,
            refresh: refresh,
            onDeleteSuccess: onDeleteSuccess,
            onTapOverride: onEntryTap,
            onLongPressOverride: onEntryLongPress,
            onSecondaryTapDown: onEntrySecondaryTapDown,
            isSelected: isEntrySelected?.call(entries[index]) ?? false,
            selectionMode: selectionMode,
            roundedCorner: roundedCorner,
            collectionTargetId: collectionTargetId,
            collectionTargetName: collectionTargetName,
          );
          final likes = likesCounts[entries[index].id] ?? 0;
          if (likes <= 0) {
            return entry;
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              entry,
              Positioned(
                top: 6,
                left: 6,
                child: IgnorePointer(
                  child: Semantics(
                    label: t.comicEntry.likes(count: likes),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likes.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }, childCount: entries.length),
      ),
    );
  }
}

class ComicSimplifyEntryGridView extends StatelessWidget {
  final List<ComicSimplifyEntryInfo> entries;
  final ComicEntryType type;
  final VoidCallback? refresh;
  final ValueChanged<String>? onDeleteSuccess;
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
  final bool roundedCorner;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const ComicSimplifyEntryGridView({
    super.key,
    required this.entries,
    required this.type,
    this.refresh,
    this.onDeleteSuccess,
    this.onEntryTap,
    this.onEntryLongPress,
    this.onEntrySecondaryTapDown,
    this.isEntrySelected,
    this.selectionMode = false,
    this.roundedCorner = true,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: buildComicSimplifyEntryGridDelegate(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return ComicSimplifyEntry(
          key: ValueKey(entries[index].id),
          info: entries[index],
          type: type,
          refresh: refresh,
          onDeleteSuccess: onDeleteSuccess,
          onTapOverride: onEntryTap,
          onLongPressOverride: onEntryLongPress,
          isSelected: isEntrySelected?.call(entries[index]) ?? false,
          selectionMode: selectionMode,
          roundedCorner: roundedCorner,
        );
      },
    );
  }
}
