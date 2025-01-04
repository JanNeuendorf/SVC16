use anyhow::Result;
use flate2::read::GzDecoder;
use macroquad::color::Color;
use macroquad::prelude::*;
use std::fs::File;
use std::io::Read;
const RES: usize = 256;

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
#[cfg(not(feature = "gamepad"))]
pub fn get_input_code() -> (u16, u16) {
    use crate::ui::Layout;

    let mp = Layout::generate().clamp_mouse();

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
