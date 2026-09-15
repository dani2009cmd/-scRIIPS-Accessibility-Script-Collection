; ============================================================
; RPCS3 QTE Assist — VISUAL DETECTION VERSION (ALWAYS-ON)
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================
; HOW THIS WORKS:
;   Runs automatically and continuously while RPCS3 is the active
;   window — no key needs to be held. It repeatedly scans a region
;   at the CENTER of your screen for one of the 4 standard
;   PlayStation button colors, and presses the matching button the
;   instant it detects one.
;
;   Sensitivity is set as high (loose) as practical, per your
;   request, to prioritize catching real prompts even at the cost
;   of more false positives ("fake alarms").
;
;   SAFETY TOGGLE: press K at any time to turn detection OFF or
;   back ON. A brief on-screen message confirms the new state.
;   This exists so you have a quick way to stop it if it ever
;   misfires somewhere you don't want it to.
;
; YOUR RPCS3 KEYBOARD MAPPING:
;   Triangle = V   |   Cross(X) = X   |   Square = B   |   Circle = C
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Detection region: a box around the center of the screen ---
BoxSize := 40
CenterX := A_ScreenWidth  // 2
CenterY := A_ScreenHeight // 2
Left    := CenterX - BoxSize
Top     := CenterY - BoxSize
Right   := CenterX + BoxSize
Bottom  := CenterY + BoxSize

; --- Button colors: sampled directly from real gameplay screenshots
;     on 2026-08-20 (previous values below were rough approximations
;     and, for Cross especially, were far off from the actual in-game
;     color - likely the main cause of missed Cross detections) ---
ColorTriangle := 0x71E298  ; mint green outline, avg of 2 screenshot samples (~113,226,152)
ColorCircle   := 0xDA5349  ; red ring, sampled from screenshot (218,83,73)
ColorCross    := 0x93A9FA  ; periwinkle blue "X", sampled (147,169,250) - was 0x0D4E8A (dark blue), very different!
ColorSquare   := 0xFF75D1  ; pink/magenta outline, sampled (255,117,209)

; --- Sensitivity: tightened now that all 4 real colors are known ---
VariationTriangle := 55  ; green (Triangle) - confirmed stable across both samples
VariationCross := 60  ; blue (Cross) - tightened now that the real, lighter color is used
VariationSquare := 60  ; pink (Square) - color is very saturated/distinct, safe to tighten
VariationCircle := 60  ; red (Circle) - now sampled from a real screenshot, tightened to match

; --- Cooldown after a successful detection, so it doesn't fire twice ---
CooldownMs := 700

Enabled := true

; --- Run continuously while RPCS3 is focused ---
SetTimer(WatchLoop, 20)

WatchLoop() {
    global Enabled
    if !Enabled
        return
    if !WinActive("ahk_exe rpcs3.exe")
        return
    Watch()
}

; --- K: toggle detection on/off, only while RPCS3 is focused ---
; (scoped so pressing "k" elsewhere - browser, chat, etc. - types normally)
#HotIf WinActive("ahk_exe rpcs3.exe")
K::
{
    global Enabled
    Enabled := !Enabled
    ToolTip(Enabled ? "QTE Assist: ON" : "QTE Assist: OFF")
    SetTimer(() => ToolTip(), -1000)
}
#HotIf

; --- Core detection loop (runs one scan pass) ---
Watch() {
    static lastFire := 0
    if (A_TickCount - lastFire < CooldownMs)
        return

    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, VariationTriangle) {
        PressOnce("v")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, VariationCircle) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCross, VariationCross) {
        PressOnce("x")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, VariationSquare) {
        PressOnce("b")
        lastFire := A_TickCount
        return
    }
}

PressOnce(key) {
    Send("{" key " down}")
    Sleep(30)
    Send("{" key " up}")
}
