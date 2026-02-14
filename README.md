# LootEnh

A World of Warcraft addon for **Ascension WoW** (3.3.0) that replaces the default loot roll frames with custom loot bars, adds a loot history panel, auto-roll automation, solo loot display, and chat filtering.

## Features

### Group Loot Bars
- Custom loot bars replacing the default Blizzard roll frames
- Configurable scale, opacity, growth direction, spacing, and frame layer
- Draggable anchor to position bars anywhere on screen
- Built-in Need/Greed/Pass/DE buttons with keyboard shortcuts

### Auto-Roll
- Automatic rolling based on item quality (green, blue, purple, legendary)
- Pre-configured rules for raid materials (MC, BWL, ZG) and Ascension-specific items (Worldforged, Mystic Scrolls)
- Custom rules by item name (shift-click to auto-fill)
- BoP protection: forces manual roll on Bind on Pickup items
- Collapsible sections per raid/category

### Solo Loot Display
- Floating bars for solo play showing: Items, Gold, XP, Reputation
- Per-module settings (enable, duration, cumulation)
- Minimum rarity filter, bag count display, quest item highlighting
- Session gold total tracker
- Chat filtering modes: Normal, Clean (hide gray/gold), Silence (hide all)

### Chat Filtering (Group)
- Three modes: Normal, Filtered (winners & your rolls only), Silence (hide all)

### Loot History
- Scrollable log of recent group loot events
- Toggle visibility via minimap button or `/lh`

### Profiles
- Save/Load/Delete named profiles for Auto-Roll settings and UI settings
- Export/Import profiles as Base64 strings
- Auto-load per character

### Localization
- English (enUS) and French (frFR)

## Installation

1. Download or clone this repository
2. Copy the `LootEnh` folder into your `Interface/AddOns/` directory
3. Restart WoW or type `/reload`

## Slash Commands

| Command | Action |
|---------|--------|
| `/ll` | Toggle loot anchors (group + solo) |
| `/lh` | Toggle loot history panel |

## Minimap Button

- **Left Click** — Show/Hide loot history
- **Shift + Left Click** — Show/Hide loot anchors
- **Right Click** — Open settings
- **Drag** — Move the minimap icon

## Configuration

Right-click the minimap button or go to **Interface > AddOns > LootEnh** to access all settings panels:

- **Main** — Language, enable/disable group frames and solo display, quick profile selection
- **Auto-Roll** — Rules per item, quality, and custom name-based rules
- **Custom Rules** — Add/remove name-based auto-roll rules
- **Group Frame** — Group bar appearance and chat filter mode
- **Solo Frame** — Solo bar modules and appearance
- **Profiles** — Save, load, export, and import configurations

## Requirements

- WoW Client 3.3.0 (Ascension / Project Ascension - Bronzebeard)
- No external library dependencies

## License

[MIT](LICENSE)
