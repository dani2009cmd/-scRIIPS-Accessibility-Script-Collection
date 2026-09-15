use std::ptr;
use std::thread;
use std::time::Duration;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_MOUSE, MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP, 
    MOUSEINPUT, VIRTUAL_KEY,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{GetAsyncKeyState, VK_ESCAPE, VK_V};

fn simulate_middle_click() {
    unsafe {
        let mut inputs: [INPUT; 2] = [std::mem::zeroed(), std::mem::zeroed()];

        // Mouse Down
        inputs[0].r#type = INPUT_MOUSE;
        inputs[0].anon.mi = MOUSEINPUT {
            dx: 0,
            dy: 0,
            mouseData: 0,
            dwFlags: MOUSEEVENTF_MIDDLEDOWN,
            time: 0,
            dwExtraInfo: 0,
        };

        // Mouse Up
        inputs[1].r#type = INPUT_MOUSE;
        inputs[1].anon.mi = MOUSEINPUT {
            dx: 0,
            dy: 0,
            mouseData: 0,
            dwFlags: MOUSEEVENTF_MIDDLEUP,
            time: 0,
            dwExtraInfo: 0,
        };

        SendInput(2, inputs.as_mut_ptr(), std::mem::size_of::<INPUT>() as i32);
    }
}

fn main() {
    println!("Rust Low-Level Clicker Running...");
    println!("Press 'v' to middle-click. Press 'Esc' to exit.");

    let mut v_was_pressed = false;

    loop {
        unsafe {
            // Check if Esc is pressed to shut down completely
            if (GetAsyncKeyState(VK_ESCAPE as i32) & 0x8000) != 0 {
                println!("Shutting down script.");
                break;
            }

            // Check if 'v' key is pressed
            let v_state = GetAsyncKeyState(VK_V as i32);
            let is_pressed = (v_state & 0x8000) != 0;

            if is_pressed && !v_was_pressed {
                simulate_middle_click();
                v_was_pressed = true;
            } else if !is_pressed {
                v_was_pressed = false;
            }
        }

        // Small sleep to keep CPU usage low
        thread::sleep(Duration::from_millis(10));
    }
}