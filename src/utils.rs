use std::io::Read;

use crate::RES;
use anyhow::Result;
use flate2::read::GzDecoder;
use pixels::Pixels;
use std::fs::File;
use winit::{
    event::MouseButton,
    event_loop::EventLoopWindowTarget,
    keyboard::{Key, KeyCode},
};
use winit_input_helper::WinitInputHelper;
#[cfg(feature = "gamepad")]
use winit_input_map::{input_map, GamepadAxis, GamepadButton, InputCode, InputMap};

#[cfg(feature = "gamepad")]
#[derive(Debug, std::hash::Hash, PartialEq, Eq, Clone, Copy)]
pub enum NesInput {
    Up,
    Down,
    Left,
    Right,
    A,
    B,
    Start,
    Select,
}

#[cfg(feature = "gamepad")]
pub fn build_gamepad_map() -> InputMap<NesInput> {
    input_map!(
        (NesInput::A, GamepadButton::East),
        (NesInput::B, GamepadButton::South),
        (NesInput::Select, GamepadButton::Select),
        (NesInput::Start, GamepadButton::Start),
        (
            NesInput::Up,
            GamepadButton::DPadUp,
            InputCode::gamepad_axis_pos(GamepadAxis::LeftStickY)
        ),
        (
            NesInput::Down,
            GamepadButton::DPadDown,
            InputCode::gamepad_axis_neg(GamepadAxis::LeftStickY)
        ),
        (
            NesInput::Left,
            GamepadButton::DPadLeft,
            InputCode::gamepad_axis_neg(GamepadAxis::LeftStickX)
        ),
        (
            NesInput::Right,
            GamepadButton::DPadRight,
            InputCode::gamepad_axis_pos(GamepadAxis::LeftStickX)
        )
    )
}

pub fn read_u16s_from_file(file_path: &str) -> Result<Vec<u16>> {
    let mut file = File::open(file_path)?;
    if file_path.ends_with(".gz") {
        read_u16s_to_buffer(&mut GzDecoder::new(file))
    } else {
        read_u16s_to_buffer(&mut file)
    }
}

fn read_u16s_to_buffer<T: Read>(reader: &mut T) -> Result<Vec<u16>> {
    let mut buffer = [0u8; 2];
    let mut u16s = Vec::new();
    while reader.read_exact(&mut buffer).is_ok() {
        let value = u16::from_le_bytes(buffer);
        u16s.push(value);
    }
    Ok(u16s)
}

fn rgb565_to_argb(rgb565: u16) -> (u8, u8, u8) {
    let r = ((rgb565 >> 11) & 0x1F) as u8;
    let g = ((rgb565 >> 5) & 0x3F) as u8;
    let b = (rgb565 & 0x1F) as u8;
    let r = (r << 3) | (r >> 2);
    let g = (g << 2) | (g >> 4);
    let b = (b << 3) | (b >> 2);
    (r, g, b)
}

pub fn update_image_buffer(imbuff: &mut [u8], screen: &[u16; RES * RES]) {
    for i in 0..RES * RES {
        let col = rgb565_to_argb(screen[i]);
        *imbuff.get_mut(4 * i).expect("Error with image buffer") = col.0;
        *imbuff.get_mut(4 * i + 1).expect("Error with image buffer") = col.1;
        *imbuff.get_mut(4 * i + 2).expect("Error with image buffer") = col.2;
        *imbuff.get_mut(4 * i + 3).expect("Error with image buffer") = 255;
    }
}
#[cfg(feature = "gamepad")]
pub fn get_input_code_gamepad(
    input: &WinitInputHelper,
    gamepad: &InputMap<NesInput>,
    pxls: &Pixels,
) -> (u16, u16) {
    let raw_mp = input.cursor().unwrap_or((0., 0.));
    let mp = match pxls.window_pos_to_pixel(raw_mp) {
        Ok(p) => p,
        Err(ev) => pxls.clamp_pixel_pos(ev),
    };
    let pos_code = (mp.1 as u16 * 256) + mp.0 as u16;
    let mut key_code = 0_u16;
    if input.key_held(KeyCode::Space)
        || input.mouse_held(MouseButton::Left)
        || gamepad.pressing(NesInput::A)
    {
        key_code += 1;
    }
    if input.key_held_logical(Key::Character("b"))
        || input.mouse_held(MouseButton::Right)
        || gamepad.pressing(NesInput::B)
    {
        key_code += 2;
    }
    if input.key_held_logical(Key::Character("w"))
        || input.key_held(KeyCode::ArrowUp)
        || gamepad.pressing(NesInput::Up)
    {
        key_code += 4;
    }
    if input.key_held_logical(Key::Character("s"))
        || input.key_held(KeyCode::ArrowDown)
        || gamepad.pressing(NesInput::Down)
    {
        key_code += 8;
    }
    if input.key_held_logical(Key::Character("a"))
        || input.key_held(KeyCode::ArrowLeft)
        || gamepad.pressing(NesInput::Left)
    {
        key_code += 16;
    }
    if input.key_held_logical(Key::Character("d"))
        || input.key_held(KeyCode::ArrowRight)
        || gamepad.pressing(NesInput::Right)
    {
        key_code += 32;
    }
    if input.key_held_logical(Key::Character("n")) || gamepad.pressing(NesInput::Select) {
        key_code += 64;
    }
    if input.key_held_logical(Key::Character("m")) || gamepad.pressing(NesInput::Start) {
        key_code += 128;
    }
    (pos_code, key_code)
}

pub fn handle_event_loop_error(handle: &EventLoopWindowTarget<()>, msg: impl AsRef<str>) {
    eprintln!("{}", msg.as_ref());
    handle.exit();
}

#[cfg(not(feature = "gamepad"))]
pub fn get_input_code(input: &WinitInputHelper, pxls: &Pixels) -> (u16, u16) {
    let raw_mp = input.cursor().unwrap_or((0., 0.));
    let mp = match pxls.window_pos_to_pixel(raw_mp) {
        Ok(p) => p,
        Err(ev) => pxls.clamp_pixel_pos(ev),
    };
    let pos_code = (mp.1 as u16 * 256) + mp.0 as u16;
    let mut key_code = 0_u16;
    if input.key_held(KeyCode::Space) || input.mouse_held(MouseButton::Left) {
        key_code += 1;
    }
    if input.key_held_logical(Key::Character("b")) || input.mouse_held(MouseButton::Right) {
        key_code += 2;
    }
    if input.key_held_logical(Key::Character("w")) || input.key_held(KeyCode::ArrowUp) {
        key_code += 4;
    }
    if input.key_held_logical(Key::Character("s")) || input.key_held(KeyCode::ArrowDown) {
        key_code += 8;
    }
    if input.key_held_logical(Key::Character("a")) || input.key_held(KeyCode::ArrowLeft) {
        key_code += 16;
    }
    if input.key_held_logical(Key::Character("d")) || input.key_held(KeyCode::ArrowRight) {
        key_code += 32;
    }
    if input.key_held_logical(Key::Character("n")) {
        key_code += 64;
    }
    if input.key_held_logical(Key::Character("m")) {
        key_code += 128;
    }
    (pos_code, key_code)
}
