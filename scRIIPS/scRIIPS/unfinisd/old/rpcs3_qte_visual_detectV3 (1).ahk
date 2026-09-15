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
;   SAFETY TOGGLE: press F8 at any time to turn detection OFF or
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
BoxSize := 150
CenterX := A_ScreenWidth  // 2
CenterY := A_ScreenHeight // 2
Left    := CenterX - BoxSize
Top     := CenterY - BoxSize
Right   := CenterX + BoxSize
Bottom  := CenterY + BoxSize

; --- Standard PlayStation button colors (approximate) ---
ColorTriangle := 0x1E9E5A  ; green
ColorCircle   := 0xE0273D  ; red
ColorCross    := 0x0D4E8A  ; blue (darkened per feedback)
ColorSquare   := 0xE0269A  ; pink/magenta

; --- Sensitivity: set as loose/forgiving as practical ---
Variation := 150  ; max practical tolerance (0-255) — very forgiving, more false positives possible

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

; --- F8: toggle detection on/off, always available ---
F8::
{
    global Enabled
    Enabled := !Enabled
    ToolTip(Enabled ? "QTE Assist: ON" : "QTE Assist: OFF")
    SetTimer(() => ToolTip(), -1000)
}

; --- Core detection loop (runs one scan pass) ---
Watch() {
    static lastFire := 0
    if (A_TickCount - lastFire < CooldownMs)
        return

    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorTriangle, Variation) {
        PressOnce("v")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCircle, Variation) {
        PressOnce("c")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorCross, Variation) {
        PressOnce("x")
        lastFire := A_TickCount
        return
    }
    if PixelSearch(&fx, &fy, Left, Top, Right, Bottom, ColorSquare, Variation) {
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
