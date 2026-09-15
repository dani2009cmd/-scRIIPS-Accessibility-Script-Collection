#SingleInstance Force
SetKeyDelay -1, -1
SendMode("Input")

OnExit(Func("HandleExit"))

; Global toggle
scriptEnabled := true

; Keep track of which trigger keys we currently consider "held" (prevents auto-repeat)
heldCombos := Map()

; NOTE: The old "K -> scroll wheel" trigger has been removed from this script.
; AHK cannot send scroll-wheel input that Lollipop Chainsaw RePOP will accept
; (it filters out software-simulated scroll events). That function should now
; be handled by a macro button on a physical mouse with onboard memory instead.
; See combo_remapper_README.md for details.

; ---- EDIT THIS LIST TO ADD/REMOVE YOUR OWN COMBOS ----
; Map of TriggerKey => Array of real keys to hold
combos := Map(
    "F1", ["l", "1"],           ; example: block + punch -> F1
    "F2", ["shift", "w"],       ; sprint + forward -> F2
    "F3", ["ctrl", "c"],        ; crouch-walk -> F3
    "F4", ["shift", "space"],   ; sprint-jump -> F4
    "F5", ["ctrl", "shift"]     ; crouch-sprint / slide -> F5
)
; --------------------------------------------------------

; Register hotkeys for each combo: down and up
for triggerKey, keys in combos {
    Hotkey("*" triggerKey, Func("PressCombo").Bind(keys, triggerKey))
    Hotkey("*" triggerKey " Up", Func("ReleaseCombo").Bind(keys, triggerKey))
}

; PressCombo: send "down" for each real key (only on first activation)
PressCombo(keys, triggerKey, *) {
    global scriptEnabled, heldCombos
    if (!scriptEnabled)
        return
    ; Prevent repeated activations (from key repeat or other duplicates)
    if (heldCombos.Has(triggerKey))
        return
    heldCombos[triggerKey] := true
    for k in keys {
        Send "{" k " down}"
    }
}

; ReleaseCombo: send "up" for each real key (only if we believe it was held)
ReleaseCombo(keys, triggerKey, *) {
    global scriptEnabled, heldCombos
    if (!scriptEnabled)
        return
    if (!heldCombos.Has(triggerKey))
        return
    heldCombos.Delete(triggerKey)
    for k in keys {
        Send "{" k " up}"
    }
}

; Toggle script on/off (panic)
F8::{
    global scriptEnabled
    scriptEnabled := !scriptEnabled
    if (!scriptEnabled) {
        ReleaseAllHeldCombos()
    }
    ToolTip scriptEnabled ? "Combo remapper: ON" : "Combo remapper: OFF"
    SetTimer RemoveToolTip, -1000
}

RemoveToolTip() {
    ToolTip
}

; Release all combos that are currently considered held.
; NOTE: builds a list of keys first, then deletes -- deleting from a Map
; while iterating over it directly can cause errors in AHK v2.
ReleaseAllHeldCombos() {
    global heldCombos, combos
    triggersToRelease := []
    for triggerKey in heldCombos {
        triggersToRelease.Push(triggerKey)
    }
    for triggerKey in triggersToRelease {
        if combos.Has(triggerKey) {
            for k in combos[triggerKey]
                Send "{" k " up}"
        }
        heldCombos.Delete(triggerKey)
    }
}

; Ensure keys are released if script exits/crashes
HandleExit(*) {
    ReleaseAllHeldCombos()
}
