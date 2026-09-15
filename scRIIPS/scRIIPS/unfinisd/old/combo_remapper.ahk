; ============================================================
; General Combo-to-Single-Key Remapper (AutoHotkey v2)
; ============================================================
; WHAT THIS DOES:
;   Turns any "hold two keys together" combo into a single key
;   you press instead. While you hold the trigger key, the
;   script holds down both real keys for you; release the
;   trigger and both are released together.
;
; HOW TO ADD YOUR OWN COMBOS:
;   Edit the "combos" list below. Each line is:
;       "TriggerKey", ["real_key_1", "real_key_2"]
;   The trigger key can be almost anything not already used
;   elsewhere (function keys, unused letters, etc).
;   The two real keys should match whatever PCSX2 (or the game)
;   has them bound to.
;
; EXAMPLES ALREADY INCLUDED (edit or delete freely):
;   F1  -> holds "l" + "1"   (example: block + punch)
;   F2  -> holds "shift" + "w"   (example: sprint + forward)
;
; CONTROLS:
;   U      -> turn the whole script on/off (panic button)
;
; NOTE: If you're also running the lockpicking macro script at
; the same time, make sure none of the trigger keys below match
; keys used in that script (it uses Caps Lock, R, T) to avoid
; conflicts. Change either script's keys if they overlap.
; ============================================================

#SingleInstance Force
SetKeyDelay -1, -1

scriptEnabled := true

; ---- EDIT THIS LIST TO ADD/REMOVE YOUR OWN COMBOS ----
combos := Map(
    "F1", ["l", "1"],       ; example: block + punch -> F1
    "F2", ["shift", "w"]    ; example: sprint + forward -> F2
)
; --------------------------------------------------------

for triggerKey, keys in combos {
    Hotkey("*" triggerKey, PressCombo.Bind(keys))
    Hotkey("*" triggerKey " Up", ReleaseCombo.Bind(keys))
}

PressCombo(keys, *) {
    global scriptEnabled
    if (!scriptEnabled)
        return
    for k in keys
        Send "{" k " down}"
}

ReleaseCombo(keys, *) {
    global scriptEnabled
    if (!scriptEnabled)
        return
    for k in keys
        Send "{" k " up}"
}

u::{
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    ToolTip scriptEnabled ? "Combo remapper: ON" : "Combo remapper: OFF"
    SetTimer RemoveToolTip, -1000
}

RemoveToolTip() {
    ToolTip
}
