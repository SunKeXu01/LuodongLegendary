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

## marinho/isometric-3d-toolkit

- Source: <https://github.com/marinho/isometric-3d-toolkit>
- License: Creative Commons Attribution 4.0 International (CC BY 4.0)
- Creator: Mario Brandao (`marinho`)
- Source commit: `95d3507560f80e44a8eb67f40807185c8d0b10fb`
- Files studied and adapted: `src/camera/IsometricCamera3D.cs`,
  `src/camera/CameraShaker.cs`, `src/core/VisibilitySwitcher.cs` and
  `src/interactions/ActivatorArea.cs`
- Actual use: `godot/scripts/isometric_camera_rig_3d.gd` translates and expands
  the upstream isometric camera / camera-shake structure into GDScript. It adds
  orthographic 2.5D projection, damped target following, bounded mouse-wheel zoom
  and deterministic shake. The world occlusion and interaction code applies the
  upstream visibility/activation separation to original cloud-ford buildings,
  NPCs, enemies and the tea-stall rest point.
- Changes: translated from C# to GDScript, removed dependencies on the upstream
  player and signal managers, and integrated with this project's existing
  NavigationAgent3D, mouse-command and save-state systems.

License text: <https://creativecommons.org/licenses/by/4.0/legalcode>

No artwork, particles, audio, characters, maps or story content from
`isometric-3d-toolkit` is included. Ming-era names, maps and story remain original;
the separately licensed CC0 visual assets used by the map are listed below.

## Relintai/broken_seals

- Source: <https://github.com/Relintai/broken_seals>
- License: MIT
- Source commit: `3b86f3bee5a225d1b9bd5810ea2684791e914347`
- Files studied: `game/ui/player/actionbars/ActionBarEntry.gd`,
  `game/ui/player/actionbars/ActionBarEntry.tscn`,
  `game/ui/player/unitframes/UnitframeBase.gd` and
  `game/ui/player/castbar/Castbar.gd`
- Actual use: the active Godot HUD adapts the generic MMO separation between
  unit frame, action slot, cooldown wipe and cast bar. The implementation in
  `godot/scripts/main.gd` is original GDScript and is integrated with this
  project's mouse-only martial-arts queue, inner-power costs, target selection
  and boss telegraph state.
- Changes: rebuilt the layout, drawing code, state model, labels and interactions
  for a single-player Ming-era wuxia ARPG.

No artwork, icons, fonts, audio, maps, story, characters or other game content
from `broken_seals` is included.

## KayKit Medieval Hexagon Pack 1.0

- Author: Kay Lousberg / KayKit
- Source: <https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0>
- Pinned commit: `84fa4e91af6a88989be7c99e0891cede11f2ca38`
- License: Creative Commons Zero 1.0
- Used assets: selected red-roof buildings, neutral structures, nature models
  and props for the Cloud Ford map.

## KayKit Character Pack: Adventures 1.0

- Author: Kay Lousberg / KayKit
- Source: <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>
- Pinned commit: `672074b73ba276876a19e8816ecdc5241817ab47`
- License: Creative Commons Zero 1.0
- Used assets: Rogue Hooded, Knight, Barbarian and Mage animated GLB models.

License text: <https://creativecommons.org/publicdomain/zero/1.0/legalcode>

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
