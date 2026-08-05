# LootEnh

> **[⬇ Download the latest release](https://github.com/Tetardtek/LootEnh/releases/latest)**


A World of Warcraft addon for **Ascension WoW** (3.3.0) **and WoW Classic Era (1.15+)** that replaces the default loot roll frames with custom loot bars, adds a loot history panel, auto-roll automation, solo loot display, and chat filtering.

> **One folder, both clients.** Modern clients read the suffixed `LootEnh_Vanilla.toc`;
> the 3.3.5 client only knows `LootEnh.toc` and ignores it. A compatibility layer
> (`Compat.lua`) absorbs the API differences at load time — same code everywhere.

## Features

### Group Loot Bars
- Custom loot bars replacing the default Blizzard roll frames
- Configurable scale, opacity, growth direction, spacing, and frame layer
- Draggable anchor to position bars anywhere on screen
- Built-in Need/Greed/Pass/DE buttons with keyboard shortcuts
- **Live roll counts**: how many players took Need, Greed, Disenchant or Pass,
  updated as they vote — hover them to see who voted what

### Visual Polish (v1.1)
- **Entry animations**: None / Fade / Slide / Pop, per frame (group & solo)
- **Exit fade** on timeout and on Need/Greed/Pass clicks
- **Epic punch**: a subtle scale kick when an epic+ item drops
- **Quality theming**: quality-colored icon border and timer bar tint
- Cropped icons (no baked-in border)

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

### Chat Filtering (v1.1 — dedicated Chat panel)
- Per-source control instead of fixed presets: one **Chat** dropdown per message
  type (group rolls, solo items, gold, XP, reputation)
- Items: Show all / Hide grays / Hide all — gold/XP/rep: Show all / Hide all
- Legacy 3-mode settings migrate automatically

### Roll Window
- Two tabs: **Active** (rolls in progress, with their live vote breakdown) and
  **History** (closed rolls, with the winner and their score)
- Roll directly from an active row — the only way to vote on rolls queued past
  the bar cap, which have no bar of their own
- Scrollable, hover a line for the per-player detail
- The last 50 closed rolls survive a reload; profiles never carry them
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
| `/lh` | Toggle the roll window |
| `/lt` | Preview the three loot tiers |
| `/lt roll` | Log raw system messages and which locale pattern matched them |
| `/lt hist` | Fill the roll window with fake data (checking layout outside a group) |

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
- **Display Frames** — Group + Solo bar appearance, quality theming and entry animation (v1.1)
- **Chat** — Per-source chat filtering for group and solo messages (v1.1)
- **Profiles** — Save, load, export, and import configurations

## Requirements

- WoW Client 3.3.0 (Ascension / Project Ascension - Bronzebeard)
- No external library dependencies

## License

[MIT](LICENSE)
