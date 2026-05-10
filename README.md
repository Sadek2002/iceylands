# Iceylands

Iceylands is a modular Roblox client UI foundation with a frosty translucent interface, loading animation, draggable window, minimized snowflake button, and JSON config support.

This first version contains UI, harmless placeholder controls, a Settings tab, config actions, and local performance toggles.
The Foraging tab uses a local `workspace.IceylandsDemo` folder for safe Studio/offline tree-position simulations and read-only audit summaries.

## Loader

After publishing this repository, update `loader.lua` with your GitHub owner name, then run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Sadek2002/iceylands/refs/heads/main/loader.lua"))()
```

## Game Lock

The UI is restricted to:

- PlaceId: `4872321990`
- GameId: `1659645941`

## Structure

```text
loader.lua
src/
  main.lua
  shared/
  core/
  ui/
  tabs/
assets/
```

Assets are downloaded from the GitHub raw URL, cached into `Iceylands/assets`, and loaded through `getcustomasset` when the executor supports it. Text fallbacks are used otherwise.

## Settings

The Settings tab currently includes:

- Disable Rendering
- FPS Boost
- Toggle UI Key
- Save Config
- Load Config
- Export Config
- Kill Script

## Foraging Demo

The Foraging tab includes:

- Best visible axe summary
- Known tree model scan
- Nearest tree distance list
- Read-only audit JSON export
- Spawn Tree Positions
- Tree Movement demo
- Tree Overlay demo
- TP To Demo Tree simulation
- Clear Tree Overlay
