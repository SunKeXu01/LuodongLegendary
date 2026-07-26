# Third-Party Notices

## Godot Engine

- Source: <https://github.com/godotengine/godot>
- License: MIT
- Version used for Windows export: 4.7.1
- Actual use: v0.4.0 and later Windows clients are exported with the Godot
  runtime. The complete engine license is included at
  `godot/ENGINE_LICENSE.txt` and installed under `licenses/GodotEngine.txt`.

## JevLOMCN/mir1

- Source: <https://github.com/JevLOMCN/mir1>
- License: Unlicense
- Source commit: `2655bb7b1103bf6514506abddcc1925a9bbd74cb`
- Files studied: `Server/MirEnvir/Map.cs`, `Server/MirObjects/MapObject.cs`, `Shared/Packet.cs`
- Actual use: `WuxiaWorldMap.ts` ports the generic rectangular-cell map, walkable-cell cache, safe-zone, blocking-object and validated-movement structure into original TypeScript. No binary map parser, network protocol values, game data, art, audio, names, maps, character designs or other Mir content is included.

The current project is an original Ming-era wuxia game and is not affiliated with the Legend of Mir / Mir franchise.

## remarkablegames/phaser-rpg

- Source: <https://github.com/remarkablegames/phaser-rpg>
- License: MIT
- Source commit: `46d12970317baf0875e646efced1eeca59471c0b`
- Source files ported: `src/scenes/Main.tsx`, `src/sprites/Player.ts`,
  `src/scenes/Boot.ts`
- Assets included and renamed for integration:
  `public/assets/tilemaps/tuxemon-town.json`,
  `public/assets/tilesets/tuxemon-sample-32px-extruded.png`,
  `public/assets/atlas/atlas.json`, and `public/assets/atlas/atlas.png`
- Actual use: the Tiled map and layer structure, tileset, sample character atlas,
  four-direction walking animations, Phaser scene lifecycle, Arcade Physics movement
  and collision, and camera-follow behavior formed the visual foundation of the
  legacy v0.3.0 Phaser scene. The active v0.4.0 Godot client does not load these
  sample assets. Original Ming-era story, UI, combat, enemies, drops, values, names,
  and game rules are implemented by this project.

The complete upstream MIT license is retained at
`src/vendor/phaser-rpg/LICENSE`. These files remain only so the historical v0.3.0
source can still be built and its license obligations remain clear.
