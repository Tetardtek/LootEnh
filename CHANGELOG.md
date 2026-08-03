# Changelog

All notable changes to LootEnh are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-08-03

### Added

- **Roll counts on the group loot bar.** Each bar now shows how many players
  picked Need, Greed, Disenchant or Pass, updating as the votes come in —
  the point being to know whether someone needs an item you are hesitating
  over. Hovering the counts lists who voted what. Roll types nobody picked are
  omitted: the useful signal is "someone took Need", not "three people did
  nothing".
- **The roll window was rebuilt around two tabs.** *Active* lists the rolls in
  progress with their live vote breakdown; *History* keeps the closed ones with
  their winner. Both scroll, and hovering a line shows the per-player detail.
  The previous panel was a single 15-line text blob with no scrolling — the
  README claimed otherwise.
- **Rolling straight from the window.** Rows in the *Active* tab carry their own
  Need/Greed/Disenchant/Pass buttons, showing only what the server still allows.
  This is not just a shortcut: past the bar cap, extra rolls are queued with no
  bar at all, so there was previously nowhere to vote on them. Your own choice
  stays lit while the others dim — they remain clickable on purpose, because a
  declined bind-on-pickup confirmation means the roll never happened. The
  *History* tab has no buttons: a closed roll cannot be played.
- **The roll log now survives a reload.** The last 50 closed rolls are stored in
  SavedVariables (`rollHistory`, capped by `histMaxEntries`). It is deliberately
  absent from `LootEnh_PROFILE_KEYS`, so an exported profile never carries its
  author's history.
- **`/lt roll`** prints every system message alongside the locale pattern that
  recognised it, or a cross when none did — the only way to verify that a
  server's roll messages match the client's `LOOT_ROLL_*` formats rather than
  assuming it. **`/lt hist`** fabricates rolls so the window can be checked
  outside a group.

### Changed

- **Roll messages are now parsed from the client's locale formats**
  (`LOOT_ROLL_NEED`, `LOOT_ROLL_ROLLED_NEED`, …) instead of hardcoded English
  fragments. A missing global disables its pattern instead of breaking. Chat
  *filtering* still uses the previous heuristics — untouched on purpose, so a
  parsing gap cannot cost the player a setting that works.
- **Roll data lives in one model** (`RollTracker.lua`) consumed by both the bar
  and the window. Parsing the chat separately in each would have let them
  diverge on the first fix.
- History window toggling is a single function (`LootEnh_ToggleHistory`) instead
  of being spelled out at each call site, and the window gained a close button.

### Fixed

- **`Everyone passed on: %s` was counted as a player named "Everyone".** That
  format is syntactically contained in `%s passed on: %s`, so the generic
  pattern matched it first. Patterns are now tried from the most literal text to
  the least — a criterion that holds in every locale, and which also covers
  `You won: %s` against `%s won: %s`.
- **A resolved roll now lingers a few seconds before moving to History**, tinted
  green when you win, red when you don't, grey when everyone passed — the tint
  fading out over the delay. Switching tabs the instant the winner was announced
  made the line vanish exactly when it became worth reading.
- **Hovering the item itself shows its in-game tooltip**, in both tabs. It is a
  separate hover zone from the row: the item answers "what is this?", the row
  answers "who wanted it?", and merging them forced a choice between the two.
  The zone tracks the actual width of the name rather than a fixed box.
- **Rows are 40px instead of 34.** The roll buttons are 20px anchored to the
  bottom and the countdown sits top-right; below 40px they shared the same
  column and the timer was buried under the buttons.
- **A roll cast anywhere but LootEnh's own bars went unrecorded.** Voting from
  the Blizzard `GroupLootFrame` (or a macro, or another addon) left the roll
  window showing nothing for you, because only our own buttons reported back.
  `RollOnLoot` is the one path every roll goes through, so it is now hooked via
  `hooksecurefunc` — the original stays intact and no taint enters a secure
  path. The three explicit call sites that duplicated this were removed; only
  the auto-roll one remains, and solely to record *where* the vote came from.
- **Auto-rolled items never appeared in the *Active* tab.** `CANCEL_LOOT_ROLL`
  does not mean "the roll is over", it means "your part in it is over" — the
  server sends it the moment you vote, which is what dismisses the native window
  while everyone else keeps choosing. Treating it as the end of the roll
  archived the item the instant auto-roll answered, so it entered and left the
  tab in the same breath. Rolls now stay tracked until the winner is announced
  (or the roll expires); only your own buttons go away. As a side effect, you
  keep watching the others vote after you have voted yourself — which was the
  whole point of the counts.
- **The winner's roll type and score could stay blank forever.** Both were
  snapshotted the moment `X won:` arrived, but the `Need Roll - 100 … by X`
  lines that carry them often land *after* — and nothing guarantees the order of
  those messages. They are now derived at display time from the vote tables,
  which keep being enriched even after the roll is archived. The roll-type icon
  also moved next to the winner's name, where it qualifies the name rather than
  the whole line.
- **Auto-rolled items now say so.** A roll the addon answered for you usually
  closes within a second, crossing the *Active* tab too fast to read; it is
  tagged `Auto: <type>` in *History* so the auto-roll no longer acts without
  reporting what it chose.
- **Rolls are tracked even when no bar is shown** (auto-roll answered, bars
  disabled, queued bar). Observing what others vote does not depend on whether
  we drew a bar for it.
- A bar leaving the queue seconds after the roll started now displays the votes
  already cast instead of starting its count from zero.

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
