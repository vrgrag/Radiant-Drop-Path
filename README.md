# Radiant Drop Path

A circuit-puzzle automation game. You lay out generators, accelerators,
splitters, magnets, converters and teleports on a neon board, then release
coloured spheres and watch them ride the path you built into the receivers
that want them.

## Modes

- **Campaign** — hand-built levels across eleven locations, each adding one
  new component to the toolbox.
- **Endless** — a procedurally generated board that keeps raising the target
  score until you miss.
- **Lab** — a free sandbox with every component unlocked, for working out a
  layout before you commit to it in a level.
- **Guide** — an in-game reference explaining what each component does to a
  sphere that enters it.

## Running the project

```bash
flutter pub get
flutter run
```

On iOS, install the pods first:

```bash
cd ios && pod install
```

## Layout

```
lib/
├── engine/    level generation, path carving, the simulation step
├── models/    grid, level, component and sphere definitions
├── screens/   menu, level select, gameplay, endless, lab, guide, settings
├── services/  save data and audio
├── theme/     palette and Material theme
└── widgets/   board rendering, HUD, palette, dialogs
```
