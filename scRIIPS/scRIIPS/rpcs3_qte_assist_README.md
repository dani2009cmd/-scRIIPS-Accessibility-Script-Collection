# RPCS3 QTE Assist — README

## What this is for
Helps with **timed single-button QTEs** in Lollipop Chainsaw (2012 original, played via
the RPCS3 emulator). Instead of needing to recognize which button icon appeared and hit
it at the exact right instant, you press **one key** and the script cycles rapidly
through all four face buttons for you.

## How to use it
1. Make sure AutoHotkey v2 is installed (same one used for `combo_remapper.ahk`).
2. Double-click `rpcs3_qte_assist_single.ahk` to run it. A small AHK icon will appear
   in your system tray while it's running.
3. Launch RPCS3 and start playing as normal.
4. Whenever a QTE prompt appears on screen, press **K**.
   - The script will hold and release Triangle (V), Cross (X), Square (B), and Circle
     (C) one at a time, cycling through them for about 1.5 seconds.
   - Only one button is ever pressed at a time — never simultaneously — to keep the
     risk of a "wrong button" penalty as low as possible.
5. To close the script, right-click its tray icon and choose Exit.

## Why K, and why cycling instead of all-at-once
- **K** was chosen because it's not used by anything in `combo_remapper.ahk`
  (which uses F1–F5 and F8), so both scripts can run at the same time safely.
- The script only activates while **RPCS3 is the focused window**, so pressing K
  anywhere else (browser, Discord, typing) does nothing unusual.
- Buttons cycle **one at a time** rather than all firing together, because it's
  unconfirmed whether this game's QTEs penalize a wrong or simultaneous press. This
  is a precaution, not a confirmed requirement — see "Known unknowns" below.
- Since the QTE button sequence is random, the script doesn't try to predict which
  button is needed — it just keeps rotating through all four so the right one is
  always hit within the window.

## Settings you can adjust
Near the top of the script:
- `BurstDurationMs := 1500` — how long the cycling burst lasts after you press K.
  Increase this if 1.5 seconds isn't enough time to cover the QTE window.
- `PressIntervalMs := 60` — time between each button press in the cycle. Lower this
  to cycle through the four buttons faster (more attempts per second).

## Known unknowns — please test carefully
- **It is not confirmed** whether pressing the wrong button during one of these QTEs
  causes a penalty or immediate fail in this specific game. This script is designed
  cautiously (one button at a time) as a precaution, not because this has been
  verified.
- Recommend testing on an early, low-stakes QTE first before relying on this in a
  harder fight, so you can see firsthand whether wrong presses cause any issue.

## Compatibility
- Works alongside `combo_remapper.ahk` (Bully script) — no key conflicts.
- Does **not** solve the Lollipop Chainsaw RePOP scroll-wheel issue (that's a
  separate, PC-only, unrelated problem — see prior notes on that topic). This script
  is specifically for the original 2012 game running through RPCS3.
