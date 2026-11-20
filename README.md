# Axonic V2

Modular Luau rewrite of Axonic.

## V2 scope
- Auto Farm and Auto Quest controller
- Mobile-first draggable UI
- Runtime diagnostics and error log
- Character respawn recovery
- Persistent settings (executor file APIs when available)
- Session statistics

## Repository status
The repository currently contains the V2 foundation modules. The original Axonic script is not stored in this repository yet, so its complete quest table and exact game-specific farming adapter still need to be migrated before the Auto Farm controller can be considered complete.

## Source layout
- `src/core/Settings.lua` — defaults, safe load/save
- `src/core/Diagnostics.lua` — bounded runtime log and status
- `src/core/Statistics.lua` — session time, kills, quests
- `src/features/CharacterManager.lua` — character/respawn lifecycle
- `src/features/Movement.lua` — cancellable segmented tween movement
- `src/ui/MobileWindow.lua` — responsive draggable control window

## Compatibility
Designed for Luau in a Roblox client environment. Persistence gracefully falls back to in-memory settings when executor file APIs are unavailable. Movement never modifies collision properties and restores no physics state because it does not disable collisions.

## Development notes
The V2 migration must keep quest selection, mob matching and combat isolated from the UI. Any unsupported or changed game remotes should be reported by Diagnostics rather than silently retried in a tight loop.
