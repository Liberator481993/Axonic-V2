# Axonic V2

Modular Luau rewrite of Axonic.

## V2 scope
- Auto Farm and Auto Quest state machine
- Mobile-first draggable UI
- Runtime diagnostics and bounded error log
- Character respawn recovery
- Persistent settings (executor file APIs when available)
- Session statistics

## Repository status
The repository now contains the V2 foundation and a game adapter. It is **not yet a ready-to-run one-file script**: the original Axonic quest route table and final bootstrap are still to be migrated. The repository did not contain the original Lua source when development began, so route names, level bands and coordinates have not been guessed.

## Source layout
- `src/core/Settings.lua` — defaults, safe load/save
- `src/core/Diagnostics.lua` — bounded runtime log and status
- `src/core/Statistics.lua` — session time, kills, quests
- `src/features/CharacterManager.lua` — character/respawn lifecycle
- `src/features/Movement.lua` — cancellable segmented tween movement; no noclip
- `src/features/GameAdapter.lua` — level, sea, quest UI, enemy lookup and melee tool adapter
- `src/features/AutoFarmController.lua` — state-driven farm/quest loop with dependency injection
- `src/ui/MobileWindow.lua` — responsive draggable control window

## Compatibility
Designed for Luau in a Roblox client environment. Persistence gracefully falls back to in-memory settings when executor file APIs are unavailable. Movement does not change collision properties. Game-specific behavior is kept behind the adapter so updates can be diagnosed without rewriting the UI.

## Remaining migration work
1. Port the original quest route table without changing its validated quest IDs and coordinates.
2. Add the bootstrap that wires settings, adapter, controller and UI together.
3. Run syntax and in-game tests for each sea; verify respawn, quest acceptance, target selection and stopping behavior.
