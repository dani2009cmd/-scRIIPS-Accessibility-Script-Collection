# scRIIPS — Accessibility Script Collection

A personal collection of input-automation and accessibility tools, mostly built for
one-handed / limited-input play on a handful of PC games (native and emulated), plus
two unrelated side projects that happen to live in the same folder. This README is a
map of the whole folder — what each thing is, which version to actually use, and what
you need to run it.

Everything here that touches a game only simulates keypresses/mouse input. Nothing
patches game files or reads/writes process memory.

## Requirements

| Tool | Get it from | Used by |
|---|---|---|
| **AutoHotkey v2** (not v1!) | https://www.autohotkey.com | Combo Remapper, Bully lockpick macros, RPCS3 QTE assist, Krita OSK, Math OSK |
| **AutoIt v3** | https://www.autoitscript.com/site/autoit/downloads/ | NMH Ultimate Accessibility OS, FF7 Universal Accessibility OS (unfinished) |
| **Rust toolchain** (only if rebuilding from source) | https://rustup.rs | `rust_clicker` (`b.rs`) |

Most tools also ship a compiled `.exe` next to the `.ahk`/`.au3` source, built with
the AutoHotkey/AutoIt compiler — you can run the `.exe` directly without installing
AutoHotkey/AutoIt, or run the source file if you have the interpreter installed and
want to see/edit what it does.

**Antivirus note:** AutoHotkey/AutoIt scripts and their compiled `.exe`s get flagged
by Windows Defender / antivirus fairly often, purely because the languages *can*
simulate input. That's expected for every tool below — open the source in a text
editor if you want to verify what it actually does before allowing it.

---

## Current tools, by game

### Bully: Scholarship Edition (PCSX2) — Combo Remapper
**File:** `combo_remapper__V8_10___gui.ahk` / `.exe` (latest, "V8.10")
**Config:** `combo_config.ini`, `remapper_global.ini`, `profiles/`

Turns held key-combos into single-key triggers, with a full GUI: unlimited combo
rows, Hold/Toggle/Press/Turbo/TapHold modes, multi-profile save/switch/import/export,
a lockable on-screen HUD, themes, a key/mouse recorder, panic-toggle hotkey, per-row
enable/disable, and a target-exe filter. See `combo_remapper_README.md` for the
original quick-start — note it documents an early version (`combo_remapper.ahk`,
F1–F5 combos only); the actual current build is far more featureful. `profiles/`
holds saved combo sets (`default.ini`, `s.ini`); `remapper_global.ini` just
remembers the last-used profile so it reopens automatically.

### Bully: Scholarship Edition (PCSX2) — Lockpicking Assist
**Files:** `bully_lockpick_macro ps 2(2).ahk` (keyboard-tap version) and
`bully_lockpick_macro_mouse.ahk` (mouse-movement version)

Automates the analog-stick rotation in the lockpicking minigame; you just watch/listen
for the lock to click and hit a hotkey to reverse direction. Two variants depending on
whether your PCSX2 binding maps the stick to WASD keys or to relative mouse movement:
Caps Lock starts/stops the auto-rotation, R reverses direction on the click, T is the
emergency stop.

### No More Heroes 1 / 2 / 3 (PC + RPCS3) — NMH Ultimate Accessibility OS
**Current file:** `unfinisd/nmh_ultimate_os_v7_1 (3).au3` (AutoIt — this is the
current build, despite living in the `unfinisd` folder)
**Config:** `nmh_config.ini`, `nmh_accessibility.ini`, `nmh_profiles/NMH1.ini`
**Older, superseded build:** top-level `UNITED ASSASSINS ASSOCIATION - NMH 3,2,1
UAA MASTER OS v6.0 (FINAL RELEASE).exe` — AutoHotkey-based, replaced by the AutoIt
rebuild above. Kept for reference only.

One-handed job/minigame automation and combat assist across all three games: Death
Blow, QTE Mash, Clash, Katana Recharge, Lawn-Mower and Toilet-Plunger minigame
automation, plus job/bike macros. Single global keybind set with a per-version
(NMH1/NMH2/NMH3) bind table, auto-detects which game is running via its process
(not window title, to avoid the tool detecting its own windows), green-terminal HUD.
The `DIS/` folder's in-universe "UAA Master OS" flavor text was written as themed
documentation/lore for this tool's UI, not functional code.

### Lollipop Chainsaw (2012, via RPCS3) — QTE Assist
**Current file:** `unfinisd/old/rpcs3_qte_visual_detect_gui.ahk` (GUI/slider version —
adjust box size, per-button color tolerance, and cooldown without editing code)
**Top-level `.bak` files** (`rpcs3_qte_assist_singleLOLIPOPP.ahk.bak`,
`rpcs3_qte_visual_detect*.ahk.bak`) are earlier iterations of the same idea, kept as
snapshots — see `rpcs3_qte_assist_README.md` for how the single-key cycling version
works, though the visual-detection GUI version above is the one actually tuned with
real sampled button colors and is the one to use.

Watches a small box at screen center for one of the four PlayStation face-button
colors (sampled from real gameplay screenshots) and presses the matching key —
no need to recognize the prompt yourself. Only one key at a time, since a wrong
press causes an immediate QTE fail in this game.

### Lollipop Chainsaw RePOP (PC remaster) — V-to-middle-click
**File:** `b.rs` (Rust source) — compiles to `rust_clicker.exe` (not included; build
with `cargo build --release`)

A small Rust/Windows utility, unrelated to AutoHotkey, that intercepts V and fires a
native `SendInput` middle-mouse-click, Escape to exit. Built because RePOP needs a
real OS-level middle-click for one of its inputs. Note: shares the V key with the
RPCS3 QTE assist script above (used there for Triangle) — don't run both at once if
they conflict.

RePOP's scroll-wheel-only sequences (e.g. the Zombie Baseball minigame) can't be
fixed by any script — Windows blocks simulated scroll input as "injected," and RePOP
filters it. That's a wall on the game/OS side, not something in this folder.

### Krita — On-Screen Keyboard
**File:** `krita_osk (4).ahk` / `.exe`

A resizable, semi-transparent, tabbed shortcut bar docked at the bottom of the
screen for one-handed use in Krita: brush, canvas/view, layers, and edit/select
tabs, a Pan hold-toggle, and a Custom tab. Sends keystrokes to whichever window was
last active (so you can click back into Krita and it still targets it).

### Math On-Screen Keyboard (school use)
**File:** `math_osk (4).ahk` / `.exe`

Same "docked bar" style as Windows' own On-Screen Keyboard, but with math
symbols/operators instead of letters — types the symbol directly into whatever's
focused. Includes a "Snap to Bottom" button; maximizing is disabled by design.

### Final Fantasy VII (1997 / Remake / Rebirth / Crisis Core Reunion) — Universal Accessibility OS
**File:** `unfinisd/ff7C 7.au3` — **unfinished / work in progress**

An AutoIt GUI intended to cover the whole FF7 line (original PC, Steam re-release,
Remake, Intergrade, Rebirth, Crisis Core Reunion) with per-title process/window
detection and rebindable hotkeys. Not complete — check the file itself for current
state before relying on it.

### Voice Coder (hands-free coding dictation)
Not included in this archive — tracked separately. It's an AHK v2 GUI
(`voice_coder.ahk`) driving an offline `faster-whisper` Python worker for
English/Hungarian speech-to-code dictation with an F5 toggle.

---

## Other folders

- **`DIS/`** — In-universe "United Assassins Association" flavor text/lore written
  as themed documentation for the NMH tool's UI and help screens. Not code.
- **`pop/`** — A separate project: a Hungarian fan-localization effort for *Popotan*
  (2002 visual novel), including `PopotanDVDTranslationTool.exe`, an existing
  Japanese→Hungarian translation cache (`windows_translation_cache.json`), patch
  reports, and Gemini-assisted scripts (`gemini-code-*.py`). Unrelated to the
  accessibility tools above.
- **`profiles/`** / **`nmh_profiles/`** — Saved keybind/combo profiles (INI files)
  for the Combo Remapper and NMH OS respectively.
- **`unfinisd/`** — Work-in-progress and in-development scripts, including the
  current NMH build and the unfinished FF7 OS (see above).
  - **`unfinisd/old/`** — Version-history graveyard: every earlier numbered/lettered
    iteration of the Combo Remapper, NMH GUI, and RPCS3 QTE scripts. Useful for
    diffing against the current build or recovering an older behavior, otherwise
    safe to ignore.

## Sub-project READMEs still in this folder

- `combo_remapper_README.md` — original quick-start for the Combo Remapper
  (documents an early version; see the summary above for what's current)
- `rpcs3_qte_assist_README.md` — quick-start for the single-key QTE cycling version
  of the Lollipop Chainsaw assist (see above for the current visual-detection
  GUI version)

## License / sharing

These are personal accessibility tools — feel free to share, modify, or
redistribute anything in this folder.
