/// All placeable component types. Order/names map 1:1 to the design
/// document's component list and to asset folders under assets/components/.
enum ComponentType {
  amplifier,
  divider,
  colorConverter,
  delay,
  intersection,
  accelerator,
  teleport,
  magnet,
  resonator,
  generator,
}

extension ComponentTypeX on ComponentType {
  /// Folder name under assets/components/ holding the skin_N.webp variants.
  String get assetFolder {
    switch (this) {
      case ComponentType.amplifier:
        return 'collection_amplifiers';
      case ComponentType.divider:
        return 'divisors';
      case ComponentType.colorConverter:
        return 'color_converters';
      case ComponentType.delay:
        return 'delays';
      case ComponentType.intersection:
        return 'intersections';
      case ComponentType.accelerator:
        return 'accelerators';
      case ComponentType.teleport:
        return 'teleports';
      case ComponentType.magnet:
        return 'magnets';
      case ComponentType.resonator:
        return 'resonator';
      case ComponentType.generator:
        return 'generators';
    }
  }

  String get displayName {
    switch (this) {
      case ComponentType.amplifier:
        return 'Amplifier';
      case ComponentType.divider:
        return 'Divider';
      case ComponentType.colorConverter:
        return 'Color Converter';
      case ComponentType.delay:
        return 'Delay';
      case ComponentType.intersection:
        return 'Intersection';
      case ComponentType.accelerator:
        return 'Accelerator';
      case ComponentType.teleport:
        return 'Teleport';
      case ComponentType.magnet:
        return 'Magnet';
      case ComponentType.resonator:
        return 'Resonator';
      case ComponentType.generator:
        return 'Generator';
    }
  }

  String get shortTag {
    switch (this) {
      case ComponentType.amplifier:
        return 'AMP';
      case ComponentType.divider:
        return 'DIV';
      case ComponentType.colorConverter:
        return 'CLR';
      case ComponentType.delay:
        return 'DLY';
      case ComponentType.intersection:
        return 'CRX';
      case ComponentType.accelerator:
        return 'ACC';
      case ComponentType.teleport:
        return 'TEL';
      case ComponentType.magnet:
        return 'MAG';
      case ComponentType.resonator:
        return 'RES';
      case ComponentType.generator:
        return 'GEN';
    }
  }

  String get description {
    switch (this) {
      case ComponentType.amplifier:
        return 'Boosts signal power of passing spheres. Does not create new flows.';
      case ComponentType.divider:
        return 'Splits one sphere into several. Multiplies flow, but weakens each output.';
      case ComponentType.colorConverter:
        return 'Repaints a sphere into another color, unlocking new interactions.';
      case ComponentType.delay:
        return 'Holds a sphere briefly to help synchronize separate routes.';
      case ComponentType.intersection:
        return 'Lets two independent lanes cross the same node without merging.';
      case ComponentType.accelerator:
        return 'Temporarily speeds up a sphere - great for deadlines, bad for sync.';
      case ComponentType.teleport:
        return 'Pair two teleports to instantly connect distant points of the board.';
      case ComponentType.magnet:
        return 'Rewards spheres that travel close together in tight formations.';
      case ComponentType.resonator:
        return 'Grants a huge bonus when multiple spheres arrive in perfect sync.';
      case ComponentType.generator:
        return 'Dormant until triggered - then floods the board with new spheres.';
    }
  }

  /// Concrete mechanical bullet points shown in the in-game Field Guide,
  /// so players know exactly what a component does instead of guessing.
  List<String> get mechanics {
    switch (this) {
      case ComponentType.amplifier:
        return [
          '+4 power to every sphere that passes through.',
          'Higher power = more score when the sphere is delivered.',
          'No downside, but it never creates new flow by itself - pair it with Dividers.',
        ];
      case ComponentType.divider:
        return [
          'Mandatory at every 3-way junction - splits one sphere into N children.',
          'Each child\'s power = parent power / N (never below 4).',
          'Great for cascades and coverage, but dilutes power per sphere.',
        ];
      case ComponentType.colorConverter:
        return [
          'Repaints a sphere to a color you choose from the level\'s palette.',
          'Use it to turn a sphere into Red/Purple right before a power-hungry component.',
          'Configure the target color right after placing it.',
        ];
      case ComponentType.delay:
        return [
          'Holds a sphere for 1-8 ticks (you choose the exact duration).',
          'The main tool for lining up two spheres to hit a Resonator together.',
          'Costs time - overusing delays can blow your simulation\'s tick budget.',
        ];
      case ComponentType.intersection:
        return [
          'Mandatory wherever two lanes cross in a clean "+" pattern.',
          'Lets a sphere continue straight through without merging lanes.',
          'Purely structural - it never boosts power or score by itself.',
        ];
      case ComponentType.accelerator:
        return [
          'Speeds a sphere up for the next 5 hops (faster tick-per-hop).',
          'Useful for beating the tick budget on long boards.',
          'Makes that sphere harder to synchronize with others afterwards.',
        ];
      case ComponentType.teleport:
        return [
          'Place two of these - anything entering one exits the other instantly.',
          'Bonus score on arrival: +6, or +10 for Purple/White spheres.',
          'A lone Teleport (no partner placed yet) just acts like plain wire.',
        ];
      case ComponentType.magnet:
        return [
          'Checks for another live sphere within 2 cells when a sphere arrives.',
          'If one is nearby: +3 power and +4 bonus score.',
          'Works best when you bunch multiple spawns/branches close together.',
        ];
      case ComponentType.resonator:
        return [
          'Remembers every hit - a second sphere landing within the sync window triggers resonance.',
          'On sync: power ×1.6 (×2.2 for Purple/White) plus big bonus score.',
          'Purple/White spheres get a wider sync window and still gain a small bonus even without a perfect sync.',
          'Pair with Delay to hand-tune two routes to arrive together.',
        ];
      case ComponentType.generator:
        return [
          'Dormant until a Yellow or White (or any high-power Red) sphere passes through.',
          'Once awake, it floods the board with up to 4 extra White spheres over time.',
          'Free extra throughput - but only if you route the right color through it first.',
        ];
    }
  }

  /// Whether this type is a "router" required by junction nodes with more
  /// than two connections (mandatory placement) versus a purely optional
  /// enhancement slotted onto a 2-way wire node.
  bool get isRouter => this == ComponentType.divider || this == ComponentType.intersection;

  /// Whether the player must choose extra configuration when placing.
  bool get needsColorConfig => this == ComponentType.colorConverter;

  bool get needsDelayConfig => this == ComponentType.delay;

  /// Number of cosmetic skin variants available for this component
  /// (see assets/components/&lt;folder&gt;/skin_0..N.webp).
  int get skinCount {
    switch (this) {
      case ComponentType.amplifier:
        return 10;
      case ComponentType.divider:
        return 10;
      case ComponentType.colorConverter:
        return 10;
      case ComponentType.delay:
        return 10;
      case ComponentType.intersection:
        return 8;
      case ComponentType.accelerator:
        return 12;
      case ComponentType.teleport:
        return 8;
      case ComponentType.magnet:
        return 15;
      case ComponentType.resonator:
        return 10;
      case ComponentType.generator:
        return 10;
    }
  }

  /// Chapter (0-based) in which this component first becomes available.
  int get unlockChapter {
    switch (this) {
      case ComponentType.amplifier:
        return 0;
      case ComponentType.delay:
        return 0;
      case ComponentType.divider:
        return 1;
      case ComponentType.intersection:
        return 3;
      case ComponentType.accelerator:
        return 2;
      case ComponentType.colorConverter:
        return 2;
      case ComponentType.teleport:
        return 3;
      case ComponentType.magnet:
        return 4;
      case ComponentType.resonator:
        return 5;
      case ComponentType.generator:
        return 6;
    }
  }
}
