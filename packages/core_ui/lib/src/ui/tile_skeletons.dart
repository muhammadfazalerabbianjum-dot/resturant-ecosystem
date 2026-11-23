import 'package:core_ui/src/ui/shapes.dart';
import 'package:core_ui/src/ui/skeleton_loader.dart';

/// Loading counterparts for the tile family (UI-3, T-6).
///
/// Each member DELEGATES to the frozen [SkeletonLoader] factories carrying
/// the DOCUMENTED dimensions of the matching live tile (asserted
/// widths/heights/radii by the batch suite):
///
/// - [stat]   — 160 x 88 compact card (StatTile: icon row + metric row)
/// - [setting]— full-width x 72 row (SettingTile: the list-row footprint)
/// - [menu]   — full-width x 96 row (MenuTile: thumbnail + text + price)
///
/// All at the large radius — the live tiles' default token radius
/// ([AppShapeTokens.cardRadius] fallback = [BrandShapes.large]). Loading
/// previews intentionally assume the default token shape: they are
/// placeholder chrome, not theme-tuned surfaces (L5 fail-safe cosmetics).
abstract final class TileSkeletons {
  /// Loading counterpart of the stat tile — compact 160 x 88 card.
  static SkeletonLoader stat() => SkeletonLoader.block(
    width: 160,
    height: 88,
    borderRadius: BrandShapes.large,
  );

  /// Loading counterpart of the setting tile — full-width 72-high row.
  static SkeletonLoader setting() => SkeletonLoader.block(
    width: double.infinity,
    height: 72,
    borderRadius: BrandShapes.large,
  );

  /// Loading counterpart of the menu tile — full-width 96-high row.
  static SkeletonLoader menu() => SkeletonLoader.block(
    width: double.infinity,
    height: 96,
    borderRadius: BrandShapes.large,
  );
}
