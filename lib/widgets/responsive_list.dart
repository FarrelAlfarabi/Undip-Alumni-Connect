import 'package:flutter/material.dart';

/// How many columns fit in [width] when a tile needs at least [minTileWidth]
/// and tiles are [gap] apart. Never less than one, never more than
/// [maxColumns].
int columnsFor(
  double width, {
  required double minTileWidth,
  double gap = 16,
  int maxColumns = 3,
}) {
  final n = ((width + gap) / (minTileWidth + gap)).floor();
  return n.clamp(1, maxColumns);
}

/// A [ListView.separated] that turns into rows of 2 or 3 tiles when there is
/// room. With one column (every phone) it builds exactly the plain list, so
/// the phone layout does not change. Rows are still built lazily.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.minTileWidth = 300,
    this.gap = 16,
    this.maxColumns = 3,
    this.padding,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder separatorBuilder;
  final double minTileWidth;
  final double gap;
  final int maxColumns;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad =
            padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;
        final inner = constraints.maxWidth - pad.horizontal;
        final cols = columnsFor(
          inner,
          minTileWidth: minTileWidth,
          gap: gap,
          maxColumns: maxColumns,
        );
        if (cols == 1) {
          return ListView.separated(
            padding: padding,
            physics: physics,
            controller: controller,
            shrinkWrap: shrinkWrap,
            itemCount: itemCount,
            separatorBuilder: separatorBuilder,
            itemBuilder: itemBuilder,
          );
        }
        final rows = (itemCount / cols).ceil();
        return ListView.separated(
          padding: padding,
          physics: physics,
          controller: controller,
          shrinkWrap: shrinkWrap,
          itemCount: rows,
          separatorBuilder: (context, r) => separatorBuilder(context, r * cols),
          itemBuilder: (context, r) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < cols; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: r * cols + c < itemCount
                      ? itemBuilder(context, r * cols + c)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A non-scrolling block of [children] laid out in 1 to [maxColumns]
/// columns by the room it gets. With one column it is a plain [Column].
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.minTileWidth = 300,
    this.gap = 16,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          gap: gap,
          maxColumns: maxColumns,
        );
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r * cols < children.length; r++)
              // Top aligned, each tile its own height: measuring rows to
              // equal heights cut off the last line of some tiles.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      child: r * cols + c < children.length
                          ? children[r * cols + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}
