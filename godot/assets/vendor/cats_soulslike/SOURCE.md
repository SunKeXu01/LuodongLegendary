# Cats Godot 4 Modular Souls-like Template

- Source: <https://github.com/catprisbrey/Cats-Godot4-Modular-Souls-like-Template>
- Pinned commit: `d8bceffc5bf4afe585a3a926fd9aa60ebd26e001`
- License: The Unlicense / public domain
- Upstream license: `LICENSE`

## Imported files

| Local file                  | Upstream Git blob                          |
| --------------------------- | ------------------------------------------ |
| `characters/mannyquin.glb`  | `3d06b3f50a74f837435b0df60740d8927d6f9be8` |
| `characters/minnyquinn.glb` | `456bf5b7a14ed707e7b0c60bf68ad54485ebc720` |
| `animations/MeleeLib.res`   | `91201065bc9f0efbc4c5446543ded556bfa12790` |

The two `.glb.import` files retain the upstream Godot humanoid bone maps so the
shared melee animation library targets the renamed humanoid skeleton correctly.
Only their `source_file` paths were changed for this repository, and external
material overrides were disabled so the client can apply role-specific colors
at runtime.

These models are used as the current mature-proportion humanoid and animation
base for the player, NPCs and enemies. They do not supply maps, story, names,
quests or gameplay rules. Their current clothing is an interim modular base,
not a claim of final Ming-period costume accuracy.
