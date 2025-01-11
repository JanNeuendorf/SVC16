#[allow(unused)]
use crate::ui::Layout;
use anyhow::Result;
use flate2::read::GzDecoder;
use macroquad::color::Color;
use macroquad::prelude::*;
use pad::PadStr;
use std::fs::File;
use std::io::Read;
const RES: usize = 256;
#[cfg(feature = "gamepad")]
use gilrs::{Axis, Button, Gilrs};

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

pub fn update_image_buffer(imbuff: &mut [Color; RES * RES], screen: &[u16; RES * RES]) {
    for i in 0..RES * RES {
        let col = rgb565_to_argb(screen[i]);
        imbuff[i] = Color {
            r: col.0 as f32 / 255.,
            g: col.1 as f32 / 255.,
            b: col.2 as f32 / 255.,
            a: 1.,
        }
    }
}

#[cfg(feature = "gamepad")]
pub fn get_input_code_gamepad(layout: &Layout, gilrs: &Gilrs) -> (u16, u16) {
    #[cfg(not(feature = "gamepad"))]
    return get_input_code_no_gamepad();
    let mut key_code = 0_u16;
    let mp = layout.clamp_mouse();
    let pos_code = (mp.1 as u16 * 256) + mp.0 as u16;
    let Some(gamepad) = gilrs.gamepads().next().map(|t| t.1) else {
        return get_input_code_no_gamepad(layout);
    };
    let tol = 0.5;
    let axis_horizontal = gamepad
        .axis_data(Axis::LeftStickX)
        .map(|a| a.value())
        .unwrap_or(0.);
    let axis_vertical = gamepad
        .axis_data(Axis::LeftStickY)
        .map(|a| a.value())
        .unwrap_or(0.);
    if is_key_down(KeyCode::Space)
        || is_mouse_button_down(MouseButton::Left)
        || gamepad.is_pressed(Button::East)
    {
        key_code += 1;
    }
    if is_key_down(KeyCode::B)
        || is_mouse_button_down(MouseButton::Right)
        || gamepad.is_pressed(Button::South)
    {
        key_code += 2;
    }
    if is_key_down(KeyCode::W)
        || is_key_down(KeyCode::Up)
        || gamepad.is_pressed(Button::DPadUp)
        || axis_vertical > tol
    {
        key_code += 4
    }
    if is_key_down(KeyCode::S)
        || is_key_down(KeyCode::Down)
        || gamepad.is_pressed(Button::DPadDown)
        || axis_vertical < -tol
    {
        key_code += 8
    }
    if is_key_down(KeyCode::A)
        || is_key_down(KeyCode::Left)
        || gamepad.is_pressed(Button::DPadLeft)
        || axis_horizontal < -tol
    {
        key_code += 16
    }
    if is_key_down(KeyCode::D)
        || is_key_down(KeyCode::Right)
        || gamepad.is_pressed(Button::DPadRight)
        || axis_horizontal > tol
    {
        key_code += 32
    }
    if is_key_down(KeyCode::N) || gamepad.is_pressed(Button::Select) {
        key_code += 64
    }
    if is_key_down(KeyCode::M) || gamepad.is_pressed(Button::Start) {
        key_code += 128
    }

    (pos_code, key_code)
}

pub fn get_input_code_no_gamepad(layout: &Layout) -> (u16, u16) {
    let mp = layout.clamp_mouse();

    let pos_code = (mp.1 as u16 * 256) + mp.0 as u16;
    let mut key_code = 0_u16;
    if is_key_down(KeyCode::Space) || is_mouse_button_down(MouseButton::Left) {
        key_code += 1;
    }
    if is_key_down(KeyCode::B) || is_mouse_button_down(MouseButton::Right) {
        key_code += 2;
    }
    if is_key_down(KeyCode::W) || is_key_down(KeyCode::Up) {
        key_code += 4
    }
    if is_key_down(KeyCode::S) || is_key_down(KeyCode::Down) {
        key_code += 8
    }
    if is_key_down(KeyCode::A) || is_key_down(KeyCode::Left) {
        key_code += 16
    }
    if is_key_down(KeyCode::D) || is_key_down(KeyCode::Right) {
        key_code += 32
    }
    if is_key_down(KeyCode::N) {
        key_code += 64
    }
    if is_key_down(KeyCode::M) {
        key_code += 128
    }

    (pos_code, key_code)
}

pub fn print_keybinds() {
    let options = vec![
        ("Input A", "Space / Mouse-Left"),
        ("Input B", "B / Mouse-Right"),
        ("Input Up", "Up / W"),
        ("Input Down", "Down / S"),
        ("Input Left", "Left / A"),
        ("Input Right", "Right / D"),
        ("Input Select", "N"),
        ("Input Start", "M"),
        ("Toggle Pause", "P"),
        ("Reload", "R"),
        ("Toggle Cursor", "C"),
        ("Toggle Verbose", "V"),
    ];

    let left_width = options
        .iter()
        .map(|(left, _)| left.len())
        .max()
        .unwrap_or(0);

    let linewidth = 40;
    println!("{}", "-".repeat(linewidth));

    for (left, right) in options {
        let padded_left = left.pad_to_width(left_width);
        println!("{}  ---  {}", padded_left, right);
    }
    println!("{}", "-".repeat(linewidth));
}
