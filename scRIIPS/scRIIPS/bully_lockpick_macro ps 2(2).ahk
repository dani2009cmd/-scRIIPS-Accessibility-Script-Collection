; ============================================================
; Bully (PCSX2) - Lockpicking Macro (AutoHotkey v2)
; ============================================================
; HOW THE MINIGAME ACTUALLY WORKS:
;   You rotate the stick one direction until you hear/feel a
;   click, then REVERSE direction until the next click, then
;   reverse back to the original direction one more time.
;   A blind macro can't detect the click itself (that's audio/
;   game-internal), so this script handles the fast, precise
;   rotation for you, and gives you a hotkey to instantly flip
;   direction the moment you notice the click.
;
; CONTROLS:
;   Caps Lock  -> Start / stop the macro
;   R          -> Reverse rotation direction (tap this the
;                 instant you hear/see the click)
;   T          -> Emergency stop
;
; SETUP:
;   1. This requires AutoHotkey v2 (autohotkey.com).
;   2. Save as bully_lockpick_macro.ahk and double-click to run.
;   3. Click into the PCSX2 window so it has focus.
;   4. Start the lockpicking minigame, press Caps Lock to begin
;      spinning, then tap R each time you notice the click/pin
;      catch. Do this twice total (reverse, then reverse again)
;      to complete the sequence.
;
; TUNING:
;   holdTime/cycleDelay below control rotation speed - lower =
;   faster. If it doesn't catch clicks well, try raising the
;   numbers so the game registers each direction change cleanly.
; ============================================================

#SingleInstance Force
SetKeyDelay -1, -1

macroActive := false
direction := 1      ; 1 = clockwise (W,D,S,A), -1 = counter-clockwise (W,A,S,D)
holdTime := 50
cycleDelay := 15

CapsLock::{
    global macroActive, direction
    macroActive := !macroActive
    if (macroActive) {
        direction := 1
        ToolTip "Lockpick macro: ON - direction: clockwise (R to reverse, T to stop)"
        SetTimer RemoveToolTip, -1500
        SpinLoop()
    } else {
        ToolTip "Lockpick macro: OFF"
        SetTimer RemoveToolTip, -1000
    }
}

r::{
    global macroActive, direction
    if (macroActive) {
        direction := direction * -1
        ToolTip "Reversed! Now: " (direction = 1 ? "clockwise" : "counter-clockwise")
        SetTimer RemoveToolTip, -800
    }
}

t::{
    global macroActive
    macroActive := false
    ToolTip "Lockpick macro: OFF (T pressed)"
    SetTimer RemoveToolTip, -1000
}

SpinLoop() {
    global macroActive, direction, holdTime, cycleDelay
    while (macroActive) {
        keys := (direction = 1) ? ["w","d","s","a"] : ["w","a","s","d"]
        for k in keys {
            if (!macroActive)
                break
            Send "{" k " down}"
            Sleep holdTime
            Send "{" k " up}"
            Sleep cycleDelay
        }
    }
}

RemoveToolTip() {
    ToolTip
}
