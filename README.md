# Iceylands

Iceylands is a modular Roblox client UI foundation with a frosty translucent interface, loading animation, draggable window, minimized snowflake button, and JSON config support.

This first version intentionally contains only UI and harmless placeholder controls.

## Loader

After publishing this repository, update `loader.lua` with your GitHub owner name, then run:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/GITHUB_OWNER/iceylands/refs/heads/main/loader.lua"))()
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
