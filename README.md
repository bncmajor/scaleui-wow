# ScaleUI

A WoW Classic addon that manages UI scale. Lets you set a scale lower than
the Blizzard built-in minimum and keeps it consistent across resolutions.

## Features

- **Custom scale** — any value from `0.10` to `1.50` (the default UI limit is `0.64` on many displays).
- **Resolution-aware presets** — presets are screen heights (720, 768, 1080, 1440). Each resolves to `preset / screenHeight`, so the "1080" preset is exactly `0.50` on a 4K display and a proportionally identical look on any monitor.
- **Control panel** — draggable dialog with live current-scale readout, preset buttons (labels show the value each resolves to on your display), custom-scale input, and tooltips.
- **Combat safe** — instant via `UIParent:SetScale`; the saved CVar write is deferred when in combat and picked up on next apply/relogin.
- **Persistence & reconciliation** — scale is saved in `ScaleUIDB`; on login it is reasserted, external changes (e.g. the system settings slider) are adopted rather than fought, and a saved scale is reapplied whenever display resolution changes.

## Usage

Open the control panel or toggle it:

```
/sui
/scaleui
```

Commands:

| Command        | Effect                                          |
|----------------|-------------------------------------------------|
| `/sui`         | Open/toggle the control panel                   |
| `/sui <n>`     | Apply a custom scale (`0.10`–`1.50`)            |
| `/sui reset`   | Back to 100%                                    |
| `/sui force`   | Re-apply the saved scale                        |
| `/sui help`    | Print the command summary                       |

In the panel: pick a preset, type a custom value and press Enter or **Apply**, or click **Reset to 100%**.

## Install

Copy the `ScaleUI/` folder into your WoW Classic `Interface/AddOns` directory:

```
.../World of Warcraft/_classic_/Interface/AddOns/ScaleUI/
```

## Notes

- First run adopts the engine's current scale so nothing jumps visually.
- Preset buttons show what each preset resolves to on your current display height.
