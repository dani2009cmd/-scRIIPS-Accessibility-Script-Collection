; ============================================================
; RPCS3 QTE Assist — Lollipop Chainsaw (2012, via RPCS3)
; SINGLE-KEY VERSION
; ============================================================
; PROBLEM THIS SOLVES:
;   Timed single-button-press QTEs are hard to hit at the exact
;   right moment, and also hard to react to fast enough to tell
;   WHICH button icon appeared. This version solves both: press
;   ONE key, and it rapid-fires all 4 face buttons together for
;   ~1.5 seconds, guaranteeing the correct one lands inside the
;   QTE's timing window no matter which icon showed up.
;
; YOUR RPCS3 KEYBOARD MAPPING:
;   Triangle = V
;   Cross(X) = X
;   Square   = B
;   Circle   = C
;
; HOTKEY (only active while RPCS3 is the focused window):
;   K -> rapid-fire V, X, B, C together
;
; This hotkey is scoped to only fire while RPCS3 is the active
; window, so it will not interfere with typing "k" anywhere else,
; or with anything in combo_remapper.ahk (F1-F5, F8).
;
; This script ONLY fires while RPCS3 is the active/focused window.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Settings you can tweak ---
BurstDurationMs := 1500   ; how long the burst lasts (milliseconds)
PressIntervalMs := 10     ; time between each round of presses (milliseconds)

; --- Scope hotkey below to only work while RPCS3 is focused ---
#HotIf WinActive("ahk_exe rpcs3.exe")

K::RapidFireAll()

#HotIf  ; end of RPCS3-only scope

; --- Core function: rapid-fires all 4 face buttons together ---
RapidFireAll() {
    keys := ["v", "x", "b", "c"]
    endTime := A_TickCount + BurstDurationMs
    while (A_TickCount < endTime) {
        for k in keys
            Send("{" k " down}")
        Sleep(20)
        for k in keys
            Send("{" k " up}")
        Sleep(PressIntervalMs)
    }
}
