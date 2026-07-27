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

## JohanAR / Oussama BOUKHELF Trail3D

- Gist: <https://gist.github.com/JohanAR/d4ad3ee23a14296b73ccfc97b6cfc0dd>
- Original author credited by the source: Oussama BOUKHELF
- Godot 4 update: JohanAR
- License: MIT
- Pinned raw revision:
  `dd9c8b3a397c2ea8f43056a3b8a6447dc577fa3a`
- Actual use: `godot/scripts/trail_3d.gd` adapts the upstream camera-facing
  triangle-strip trail technique for short-lived martial-arts weapon arcs.
- Changes: replaced the original three-point smoothing state with a bounded,
  age-based sample buffer; added vertex alpha/width profiles; exposed an
  explicit stop-emitting lifecycle; and integrated the trail with the original
  skill colors, impact effects and cleanup timing in `combat_vfx_3d.gd`.

No upstream artwork, textures, maps, gameplay data or story content is included.

## KayKit Medieval Hexagon Pack 1.0

- Author: Kay Lousberg / KayKit
- Source: <https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0>
- Pinned commit: `84fa4e91af6a88989be7c99e0891cede11f2ca38`
- License: Creative Commons Zero 1.0
- Used assets: selected neutral structures, nature models and props for the
  Cloud Ford map. The former European blacksmith and market building silhouettes
  are no longer instantiated by the active map.

## KayKit Character Pack: Adventures 1.0

- Author: Kay Lousberg / KayKit
- Source: <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>
- Pinned commit: `672074b73ba276876a19e8816ecdc5241817ab47`
- License: Creative Commons Zero 1.0
- Used assets: Rogue Hooded, Knight, Barbarian and Mage animated GLB models.

License text: <https://creativecommons.org/publicdomain/zero/1.0/legalcode>

## Polygonal Mind CC0 GLB collection

- Original creator: Polygonal Mind
- Conversion/source repository:
  <https://github.com/ToxSam/cc0-models-Polygonal-Mind>
- Pinned source commit: `56db2d4088512531a070d0bf3eb9d284d077528d`
- License: Creative Commons Zero 1.0 Universal
- Used collections: `projects/tomb-chaser-2` and `projects/lunar-year`
- Used assets: selected temple wall, column, beam, roof-corner, staircase,
  gateway and lantern GLB models.
- Actual use: the models are composed in Godot into the Cloud Ford inn,
  residence, blacksmith, warehouse, traditional gateway and street details.
  The map layout, building composition, names, collision/navigation, occlusion
  and gameplay integration are original to this project.

No upstream map, neon advertisements, gameplay, code, characters, names or
story content is included. The exact imported files and license link are
recorded in `godot/assets/vendor/polygonal_mind/SOURCE.md`.

## catprisbrey/Cats-Godot4-Modular-Souls-like-Template

- Source:
  <https://github.com/catprisbrey/Cats-Godot4-Modular-Souls-like-Template>
- Pinned source commit: `d8bceffc5bf4afe585a3a926fd9aa60ebd26e001`
- License: The Unlicense / public domain
- Used assets: `mannyquin.glb`, `minnyquinn.glb` and `MeleeLib.res`
- Actual use: mature-proportion modular humanoids replace the former active
  KayKit player, NPC and enemy silhouettes. The shared humanoid animation
  library supplies idle, walking, running, melee, hit and defeat actions.
- Changes: retained the upstream Godot humanoid bone maps, disabled external
  material overrides, applied original role-specific palettes and selectively
  hid armor modules for civilian roles.

The project uses these assets as an interim body, rig and animation foundation.
Original names, roles, combat rules, maps, UI and Ming-era story remain this
project's work. Exact file provenance and checksums are recorded in
`godot/assets/vendor/cats_soulslike/SOURCE.md` and `SHA256SUMS`.

## Poly Haven ground materials

- Provider: Poly Haven
- License: Creative Commons Zero 1.0 Universal
- Assets: [Mud Forest](https://polyhaven.com/a/mud_forest) and
  [Grassy Cobblestone](https://polyhaven.com/a/grassy_cobblestone)
- Used files: 1K JPG diffuse, OpenGL normal and ARM maps for each material
- Actual use: tiled PBR terrain and merchant-road materials in Cloud Ford.

The original texture images are unmodified. Godot applies project-specific UV
scales and muted Ming-wuxia color tints at runtime. Exact files, authors,
channel usage and SHA-256 checksums are recorded under
`godot/assets/vendor/poly_haven/`.

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
