# BuffWatch

A lightweight self-buff and weapon-enchant tracker for **World of Warcraft: Wrath of the Lich King (3.3.5a)**.

BuffWatch shows a compact row (or column) of icons for the buffs your class can cast. Missing buffs **glow** with a pulsing red ring; active buffs are **dimmed** with a live countdown. Click an icon to cast the buff — no need to dig through your spellbook.

## Features

- Tracks class self-buffs (Fortitude, armors, shields, seals, presences, Mark of the Wild, and more) and only shows the ones you actually know.
- Tracks weapon imbues and rogue poisons (Windfury, Flametongue, Instant Poison, etc.) by reading the weapon tooltip directly, which is reliable on custom servers.
- Missing buffs glow; active buffs dim and show a colour-coded countdown (white → yellow under a minute → red under 10 seconds). Permanent buffs show an infinity symbol.
- **Click to cast** via a secure button: left-click casts the spell; for weapon imbues, left-click applies to the main hand and right-click to the off hand.
- Grouped buffs (seals, Death Knight presences) count as satisfied when any one in the group is active.
- Automatically hides a base spell once you learn its upgrade (e.g. Demon Skin → Demon Armor, Frost Armor → Ice Armor).
- Movable, lockable frame with adjustable scale and opacity, and horizontal or vertical layout.

## Screenshots

**Buffs needed** — missing buffs glow:

![Buffs needed](https://github.com/user-attachments/assets/07256b21-70c6-447d-948e-bc8af0201c44)

**Buffs applied** — active buffs dim with timers:

![Buffs applied](https://github.com/user-attachments/assets/7c6ae75c-08be-496b-94ff-7e2ff5458757)

**Config panel:**

![Config](https://github.com/user-attachments/assets/a174a0eb-df34-4305-a189-2c2115b1d2f1)

## Installation

1. Download or clone this repository.
2. Copy the `BuffWatch` folder into your WoW directory under `Interface\AddOns\`, so the path is `Interface\AddOns\BuffWatch\BuffWatch.toc`.
   - If you downloaded a ZIP from GitHub, the extracted folder may be named `BuffWatch-main`. Rename it to `BuffWatch`.
3. Restart the game or reload the UI (`/reload`) and enable **BuffWatch** on the character-select AddOns list.

## Usage

| Command | Action |
| --- | --- |
| `/bw` or `/buffwatch` | Show / hide the BuffWatch frame |
| `/bw config` | Open the configuration panel (lock, scale, opacity, orientation) |

Drag the frame to move it (when unlocked). Settings are saved per account in `BuffWatchDB`.

## Author

Valdstein - AI was used in the creation of this addon

## License

Released under the MIT License. See [LICENSE](LICENSE).
