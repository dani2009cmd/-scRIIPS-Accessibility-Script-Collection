; ============================================================
; RPCS3 QTE Assist — VISUAL DETECTION VERSION
; Lollipop Chainsaw (2012, via RPCS3)
; ============================================================
; HOW THIS WORKS:
;   Hold down K. While held, the script repeatedly scans a small
;   region at the CENTER of your screen, looking for one of the
;   4 standard PlayStation button colors:
;     Triangle = green
;     Circle   = red
;     Cross(X) = blue
;     Square   = pink/magenta
;   The instant it detects one, it presses ONLY that matching
;   button once, then pauses briefly before scanning again (to
;   avoid firing twice on the same prompt).
;
; IMPORTANT — READ THIS:
;   The colors below are built from the STANDARD/well-known Sony
;   PlayStation button colors, NOT from an actual screenshot of
;   your game (none was available). This means detection may be
;   inaccurate at first. You said you'd test carefully — please do:
;   try it on a low-stakes QTE first, since a wrong detection will
;   press the wrong button, which you've confirmed causes an
;   instant mini-game fail.
;
;   If it's missing detections or firing wrong buttons, tell me
;   what actually happened (which button fired vs. which was
;   needed) and I can adjust the color values or detection region.
;
; YOUR RPCS3 KEYBOARD MAPPING:
;   Triangle = V   |   Cross(X) = X   |   Square = B   |   Circle = C
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Detection region: a box around the center of the screen ---
; Adjust BoxSize if the prompt appears bigger/smaller or off-center.
BoxSize := 200
CenterX := A_ScreenWidth  // 2
CenterY := A_ScreenHeight // 2
Left    := CenterX - BoxSize
Top     := CenterY - BoxSize
Right   := CenterX + BoxSize
Bottom  := CenterY + BoxSize

; --- Standard PlayStation button colors (approximate) ---
; Format: 0xRRGGBB. Tolerance (Variation) allows for lighting/shading.
ColorTriangle := 0x1E9E5A  ; green
ColorCircle   := 0xE0273D  ; red
ColorCross    := 0x1276C9  ; blue
ColorSquare   := 0xE0269A  ; pink/magenta
Variation     := 45        ; color-matching tolerance (0-255, higher = looser match)

; --- Cooldown after a successful detection, so it doesn't fire twice ---
CooldownMs := 700

; --- Scope everything below to only run while RPCS3 is focused ---
#HotIf WinActive("ahk_exe rpcs3.exe")

$K::
{
    while GetKeyState("k", "P") {
        Watch()
        Sleep(20)
    }
}

#HotIf

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
