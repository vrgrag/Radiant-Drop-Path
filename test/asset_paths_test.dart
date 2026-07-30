import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_drop_path/models/ball_color.dart';
import 'package:radiant_drop_path/models/component_type.dart';
import 'package:radiant_drop_path/utils/asset_paths.dart';

/// Every path [AssetPaths] can produce must exist on disk. A renamed or
/// re-encoded asset otherwise fails silently at runtime as a blank tile.
void main() {
  void expectExists(String assetPath) {
    expect(
      File(assetPath).existsSync(),
      isTrue,
      reason: 'missing asset: $assetPath',
    );
  }

  test('component skins exist for every type and skin index', () {
    for (final type in ComponentType.values) {
      final skins = type.skinCount == 0 ? 1 : type.skinCount;
      for (var i = 0; i < skins; i++) {
        expectExists(AssetPaths.componentIcon(type, i));
      }
    }
  });

  test('ball, start point and receiver icons exist', () {
    for (final color in BallColor.values) {
      expectExists(AssetPaths.ballIcon(color));
    }
    expectExists(AssetPaths.startPointIcon());
    expectExists(AssetPaths.receiverIcon());
  });

  test('every chapter background exists', () {
    for (var chapter = 1; chapter <= 11; chapter++) {
      expectExists(AssetPaths.chapterBackground(chapter));
    }
  });

  test('logo and loading art exist', () {
    expectExists(AssetPaths.gameLogo);
    expectExists(AssetPaths.verticalLoading);
    expectExists(AssetPaths.horizontalLoading);
  });

  test('every asset a screen loads is declared in pubspec', () {
    final declared = <String>[];
    var inAssets = false;
    for (final line in File('pubspec.yaml').readAsLinesSync()) {
      if (line.trimRight() == '  assets:') {
        inAssets = true;
        continue;
      }
      if (!inAssets) continue;
      final trimmed = line.trim();
      if (trimmed.startsWith('- ')) {
        declared.add(trimmed.substring(2));
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        break;
      }
    }

    bool isDeclared(String asset) => declared.any(
      (entry) => entry.endsWith('/') ? asset.startsWith(entry) : entry == asset,
    );

    for (final asset in <String>[
      AssetPaths.gameLogo,
      AssetPaths.verticalLoading,
      AssetPaths.horizontalLoading,
      AssetPaths.chapterBackground(1),
      AssetPaths.componentIcon(ComponentType.values.first, 0),
      'assets/beacon/notify_v.jpg',
      'assets/beacon/notify_h.jpg',
      'assets/beacon/offline_v.jpg',
      'assets/beacon/offline_h.jpg',
    ]) {
      expect(isDeclared(asset), isTrue, reason: 'not in pubspec: $asset');
    }
  });
}
