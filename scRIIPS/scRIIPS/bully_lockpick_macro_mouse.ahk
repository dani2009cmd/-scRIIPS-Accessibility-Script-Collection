; ============================================================
; Bully (PCSX2) - Lockpicking Macro (Mouse Movement version)
; AutoHotkey v2
; ============================================================
; COMPATIBILITY:
;   - PCSX2 (original Bully): REQUIRES the left analog stick
;     bound to "Relative Mouse" in Settings -> Controllers ->
;     Pad 1 -> Left Analog.
;   - Bully: Scholarship Edition (Steam): works directly, no
;     rebinding needed - the Steam version reads raw mouse
;     movement natively for lockpicking. Just make sure the
;     game window has focus before starting the macro.
;     Some players report needing to raise in-game mouse
;     sensitivity (try ~3-4x) for the rotation to register
;     cleanly - adjust in the game's control settings if the
;     circle doesn't seem to move the lock much.
; ============================================================; WHAT IT DOES:
;   Moves the mouse cursor in a smooth circle automatically,
;   which PCSX2 translates into stick rotation. This simulates
;   physically spinning the mouse in circles.
;
; HOW THE LOCK ACTUALLY WORKS:
;   Rotate one direction until you hear/see a click, reverse,
;   click again, then reverse back to the original direction
;   once more. The macro can't detect the click itself, so you
;   control the reversal manually with a hotkey.
;
; CONTROLS (keyboard - your hands are free since the mouse
; is being moved automatically):
;   Caps Lock  -> Start / stop the circular motion
;   R          -> Reverse rotation direction (press the instant
;                 you notice the click)
;   T          -> Emergency stop
;
; TUNING (edit the values below):
;   radius      -> size of the circle in pixels (bigger circle
;                  can register more clearly, but too big may
;                  overshoot on small screens)
;   stepDelay   -> ms between each small movement step (lower
;                  = faster rotation)
;   stepsPerRev -> how many small movements make one full circle
;                  (higher = smoother but slightly slower)
; ============================================================

#SingleInstance Force
SetKeyDelay -1, -1

macroActive := false
direction := 1        ; 1 = clockwise, -1 = counter-clockwise
radius := 60
stepDelay := 8
stepsPerRev := 36      ; 10 degrees per step

CapsLock::{
    global macroActive, direction
    macroActive := !macroActive
    if (macroActive) {
        direction := 1
        ToolTip "Lockpick macro: ON - clockwise (R to reverse, T to stop)"
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
    global macroActive, direction, radius, stepDelay, stepsPerRev
    angle := 0.0
    angleStep := 360.0 / stepsPerRev

    ; remember previous point on the circle so we can send
    ; relative deltas (matches PCSX2's Relative Mouse input)
    prevX := radius * Cos(0)
    prevY := radius * Sin(0)

    while (macroActive) {
        angle += angleStep * direction
        radAngle := angle * 0.0174533   ; degrees to radians
        curX := radius * Cos(radAngle)
        curY := radius * Sin(radAngle)

        dx := Round(curX - prevX)
        dy := Round(curY - prevY)

        if (dx != 0 || dy != 0)
            MouseMove dx, dy, 0, "R"

        prevX := curX
        prevY := curY

        Sleep stepDelay
    }
}

RemoveToolTip() {
    ToolTip
}
