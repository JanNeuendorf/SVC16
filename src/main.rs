mod cli;
mod engine;

use anyhow::{anyhow, Result};
use clap::Parser;
use cli::Cli;
use engine::Engine;
use minifb::{Key, Scale, Window, WindowOptions};
use std::time::Instant;
const RES: usize = 256;

fn main() -> Result<()> {
    let cli = Cli::parse();
    let initial_state = read_u16s_from_file(&cli.program)?;
    let mut engine = Engine::new(initial_state);
    let mut options = WindowOptions::default();

    options.scale = match cli.scaling {
        1 => Scale::X1,
        2 => Scale::X2,
        4 => Scale::X4,
        8 => Scale::X8,
        16 => Scale::X16,
        _ => return Err(anyhow!("Scaling must be 1,2,4,8 or 16")),
    };

    let mut image_buffer = vec![0_u32; RES * RES];
    let mut window = Window::new("SVC16", RES, RES, options)?;
    window.set_target_fps(30);
    window.set_cursor_visibility(cli.cursor);
    while window.is_open() && !window.is_key_down(Key::Escape) {
        let mut ipf = 0_usize;
        let start = Instant::now();
        while !engine.wants_to_sync() {
            if let Some(debug_vals) = &cli.debug {
                print_debug_info(debug_vals, &engine);
            }
            engine.step()?;
            ipf += 1;
            if ipf >= cli.max_ipf {
                break;
            }
        }
        let frametime = start.elapsed();
        let input_code = get_input_code(&window);
        let screenview = engine.perform_sync(input_code.0, input_code.1);
        update_image_buffer(&mut image_buffer, &screenview);
        window.update_with_buffer(&image_buffer, RES, RES)?;
        if cli.verbose {
            println!(
                "frame needed {} instructions ({}ms)",
                ipf,
                frametime.as_millis()
            );
        }
    }
    Ok(())
}

fn read_u16s_from_file(file_path: &str) -> Result<Vec<u16>> {
    use std::io::{BufReader, Read};
    let file = std::fs::File::open(file_path)?;
    let mut reader = BufReader::new(file);
    let mut buffer = [0u8; 2];
    let mut u16s = Vec::new();
    while reader.read_exact(&mut buffer).is_ok() {
        let value = u16::from_le_bytes(buffer);
        u16s.push(value);
    }
    Ok(u16s)
}

fn rgb565_to_argb(rgb565: u16) -> u32 {
    let r = ((rgb565 >> 11) & 0x1F) as u8;
    let g = ((rgb565 >> 5) & 0x3F) as u8;
    let b = (rgb565 & 0x1F) as u8;
    let r = (r << 3) | (r >> 2);
    let g = (g << 2) | (g >> 4);
    let b = (b << 3) | (b >> 2);
    (0xFF << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
}

fn update_image_buffer(imbuff: &mut Vec<u32>, screen: &[u16; RES * RES]) {
    for i in 0..RES * RES {
        *imbuff.get_mut(i).expect("Error with image buffer") = rgb565_to_argb(screen[i]);
    }
}

fn get_input_code(window: &Window) -> (u16, u16) {
    let mp = window.get_mouse_pos(minifb::MouseMode::Clamp).unwrap();
    let pos_code = mp.1 as u16 * 256 + mp.0 as u16;
    let mut key_code = 0_u16;
    if window.get_mouse_down(minifb::MouseButton::Left) || window.is_key_down(Key::Space) {
        key_code += 1;
    }
    if window.get_mouse_down(minifb::MouseButton::Right) || window.is_key_down(Key::B) {
        key_code += 2;
    }
    if window.is_key_down(Key::Up) || window.is_key_down(Key::W) {
        key_code += 4;
    }
    if window.is_key_down(Key::Down) || window.is_key_down(Key::S) {
        key_code += 8;
    }
    if window.is_key_down(Key::Left) || window.is_key_down(Key::A) {
        key_code += 16;
    }
    if window.is_key_down(Key::Right) || window.is_key_down(Key::D) {
        key_code += 32;
    }
    if window.is_key_down(Key::N) {
        key_code += 64;
    }
    if window.is_key_down(Key::M) {
        key_code += 128;
    }

    (pos_code, key_code)
}

fn print_debug_info(debug_vals: &Vec<u16>, engine: &Engine) {
    let ptr = engine.get_instruction_pointer();
    let inst = engine.read_instruction();
    for d in debug_vals {
        println!("@{}={}", d, engine.get(*d));
    }
    println!(
        "prt:{}, opcode:{}, args:[{},{},{}], @args:[{},{},{}]",
        ptr,
        inst[0],
        inst[1],
        inst[2],
        inst[3],
        engine.get(inst[1]),
        engine.get(inst[2]),
        engine.get(inst[3])
    );
}
