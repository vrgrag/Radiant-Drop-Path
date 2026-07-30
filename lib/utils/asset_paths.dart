import '../models/ball_color.dart';
import '../models/component_type.dart';

/// Central helper for building asset paths so screens never hand-write
/// path strings.
class AssetPaths {
  AssetPaths._();

  static String componentIcon(ComponentType type, int skinIndex) {
    final safe = type.skinCount == 0 ? 0 : skinIndex % type.skinCount;
    return 'assets/components/${type.assetFolder}/skin_$safe.webp';
  }

  static String ballIcon(BallColor color) {
    return 'assets/components/collection_sphere/skin_${color.assetIndex}.webp';
  }

  static String startPointIcon([int skin = 0]) => 'assets/components/starting_points/skin_$skin.webp';

  static String receiverIcon([int skin = 0]) => 'assets/components/receivers/skin_$skin.webp';

  /// Background art for a chapter (1..11 exist as bg_location assets).
  static String chapterBackground(int index) {
    final safe = ((index - 1) % 11) + 1;
    return 'assets/bg_location_${safe}_asset.webp';
  }

  static const String gameLogo = 'assets/Game_Name.png';
  static const String verticalLoading = 'assets/Vertical_Loading_Screen.png';
  static const String horizontalLoading = 'assets/Horizontal_Loading_Screen.png';
}
