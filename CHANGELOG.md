# Changelog

All notable changes to LootEnh are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-08-02

### Changed
- **LootEnh declares itself to AllEnh** when the hub is installed, so a single
  version check covers the whole Enh suite instead of one per addon. The line
  does nothing without the hub — LootEnh has no dependency on it and never will.

## [1.2.0] - 2026-08-02

### Fixed

- **Group rolls could be lost entirely.** Four defects combined into one: the
  *Need* button was shown even when the server refused that roll, clicking it
  dismissed the bar anyway, and because LootEnh unregisters the Blizzard roll
  frame there was no fallback left — no buttons, no roll, and a countdown to
  wait out. Roll buttons are now built from what the server actually allows,
  and a refused click no longer takes your remaining choices away.
- **Bind-on-pickup items lost the roll when the confirmation was declined.**
  Rolling on such an item does not register anything: it opens a confirmation.
  The bar was dismissed while that dialog was still on screen, so declining it
  left you with neither. The bar now waits for the roll to actually close —
  the same thing the native window does.
- **Cancelled rolls left a bar counting down over nothing.** `CANCEL_LOOT_ROLL`
  was listened to by nobody, since LootEnh removes it from the default UI.
- **Saving a profile over an existing one destroyed it silently.** Three of the
  four save paths (Save with no selection, Save As, Import) wrote straight to
  storage, and announced "saved" rather than "overwritten". Deleting a profile
  had always asked for confirmation; overwriting one now does too.
- **Settings added inside an existing group never reached your saved
  variables.** Defaults were merged two levels deep, so anything new under
  `solo.loot` or `solo.gold` stayed missing forever — invisible and
  unconfigurable. The merge is now recursive.
- **Editing a setting could corrupt the defaults for the session.** The same
  merge handed default sub-tables to the database *by reference* instead of
  copying them.
- **An unknown language brought the addon down.** The locale lookup had no
  fallback, so any value outside enUS/frFR resolved to nothing.
- **Solo bar settings were writing over the group bar widgets.** Sliders and
  dropdowns took their global name from their parent frame plus the setting
  key, so the two sections of the Display panel — which configure the same
  things for two different kinds of bar — produced identical names. The solo
  widgets overwrote the group ones, their labels landed on the wrong objects,
  and their own range text stayed at the Blizzard default. Names are now
  unique regardless of parent or key.
- Reputation settings overlapped the Experience section in the Display panel.

### Added

- **Disenchant rolls.** The button never existed, although the addon already
  read whether disenchanting was offered.
- **Loot bars graded by rarity.** Three tiers rather than a single uniform bar:
  common items are short, thin and faded; the normal tier is unchanged; rare
  and above are taller, held longer, brightly outlined, with an optional sound.
  The point is contrast, not nuance.
- **Common items are shown at all.** Minimum rarity now defaults to *Poor*
  instead of *Uncommon* — for new installations. Hiding them was the only
  answer the addon had to a crowded screen; grading them is a better one, and
  it does not throw the information away.
- **A separate anchor for gold, XP and reputation.** They shared the loot
  bars' list and bar limit, so a stray experience gain could push an epic drop
  off your screen. Both flows now have their own movable anchor and their own
  limit.
- `/lt` shows the three rarity tiers side by side, so the contrast can be
  judged without farming for it.
- **Settings that existed without any way to reach them** are now in the
  Display panel: the rarity thresholds for grading, the bar limit for the
  progress flow, and the history window's opacity.

### Changed

- Bars are stacked using their real heights instead of a fixed step, now that
  heights vary between tiers.
- The version lives in the `.toc` alone (`## Version`), readable through
  `GetAddOnMetadata`. It used to be written into the title, where no code
  could read or check it.

### Removed

- Seven unused locale keys left over from earlier naming. Every remaining key
  is used, and both languages hold exactly the same 141.

## [1.1] - 2026-07

### Added
- Quality theming, entry animations, unified Display and Chat panels.
- Filtering by loot source.

## [1.0] - 2026-07

### Added
- Custom loot bars for group rolls, with configurable anchor, growth
  direction, scale, opacity and spacing.
- Solo loot bars for items, gold, experience and reputation.
- Loot history window.
- Chat filtering for roll and loot messages.
- Auto-roll rules: per quality, per scroll type, per instance-specific item
  (Zul'Gurub, Molten Core, Blackwing Lair, Worldforged), plus custom
  per-item rules.
- Profiles with save, load, delete, export and import.
- English (enUS) and French (frFR) localization.
- Bridge to BagsEnh: new loot is announced so the bags can highlight it.

[1.3.0]: https://github.com/Tetardtek/LootEnh/releases/tag/v1.3.0
[1.2.0]: https://github.com/Tetardtek/LootEnh/releases/tag/v1.2.0
