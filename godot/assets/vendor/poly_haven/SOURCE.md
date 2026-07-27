# Poly Haven CC0 ground materials

- Provider: Poly Haven
- License: Creative Commons Zero 1.0 Universal
- License page: <https://polyhaven.com/license>
- Files API: <https://api.polyhaven.com>

## Mud Forest

- Asset page: <https://polyhaven.com/a/mud_forest>
- Author: eye-candy.xyz
- Used files: 1K JPG diffuse, OpenGL normal and ARM maps
- Actual use: tiled terrain material for the wet soil, leaf litter and organic
  ground surrounding Cloud Ford.

## Grassy Cobblestone

- Asset page: <https://polyhaven.com/a/grassy_cobblestone>
- Authors: Charlotte Baglioni and Dario Barresi
- Used files: 1K JPG diffuse, OpenGL normal and ARM maps
- Actual use: tiled PBR material for the Cloud Ford merchant road and raised
  weathered stone details.

The ARM images pack ambient occlusion in red, roughness in green and metallic in
blue. Godot reads those channels separately through one shared texture. The
source images are unchanged; only their material scale and color tint are
configured by the game.
