# Bully (PCSX2) — Lockpicking Assist Macro

A small AutoHotkey script that helps with the lockpicking minigame in *Bully*
when playing on the PCSX2 emulator with a keyboard instead of a controller.

## What it does

The lockpicking minigame normally requires rotating an analog stick smoothly.
On keyboard, that's hard to replicate. This script rapidly taps the
direction keys in sequence to simulate a fast stick rotation, and gives you
a hotkey to instantly reverse direction the moment you notice the lock
"click" — which is the actual trick to solving the lock (rotate one way
until it clicks, reverse, then reverse back once more).

## Requirements

- **AutoHotkey v2** — download free from [autohotkey.com](https://www.autohotkey.com)
- PCSX2 emulator with *Bully* set up, keyboard controls bound to **WASD**
  for the left analog stick (up/left/down/right)

## Installation

1. Install AutoHotkey v2 if you don't already have it.
2. Download `bully_lockpick_macro.ahk`.
3. Double-click the file to run it. You'll see a small green "H" icon
   appear in your system tray (bottom-right of your screen) — that means
   it's running in the background.

## Controls

| Key | Action |
|---|---|
| **Caps Lock** | Start / stop the auto-rotation |
| **R** | Reverse rotation direction (press this the instant you hear/see the lock click) |
| **T** | Emergency stop |

## How to use it in-game

1. Launch *Bully* in PCSX2 and click into the game window so it has focus.
2. Walk up to a lockable locker and start the lockpicking minigame as normal.
3. Press **Caps Lock** — the script will start rotating for you (clockwise
   by default).
4. Watch/listen for the lock to click. The moment it does, tap **R** to
   reverse direction.
5. Watch for the second click, tap **R** again to reverse back to the
   original direction.
6. The locker should pop open. Press **Caps Lock** again to stop the
   macro, or leave it running for the next locker.

## Tuning rotation speed

If the game doesn't seem to register the direction changes well, open the
`.ahk` file in a text editor and look near the top for:

```
holdTime := 50
cycleDelay := 15
```

- **Raise these numbers** (e.g. `70` / `25`) to slow the rotation down —
  helps if the game is missing inputs.
- **Lower them** to speed it up.

Save the file and re-run it after any changes.

## Important notes for anyone using this

- This only works while the PCSX2 window is focused — it sends keystrokes
  to whatever window is active, so make sure the game has focus before
  toggling it on.
- This is an input-automation tool for a single-player game running on an
  emulator, for personal convenience. It doesn't modify game files or
  memory — it only simulates keyboard presses.
- Rebinding: if your PCSX2 stick keys aren't WASD, open the script and
  change the `"w","d","s","a"` / `"w","a","s","d"` letters in the
  `SpinLoop()` function to match your own bindings.
- Antivirus software occasionally flags AutoHotkey scripts as suspicious
  because the language *can* be used to build unwanted automation tools —
  this one only does what's described above. Users can open the `.ahk`
  file in any text editor to read exactly what it does before running it.

## License / sharing

Feel free to share, modify, or redistribute this script freely.
