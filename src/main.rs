mod cli;
mod engine;

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use cli::Cli;
use engine::Engine;
use minifb::{Scale, Window, WindowOptions};
use pixels::{Error, Pixels, SurfaceTexture};
use std::time::Instant;
use winit::dpi::LogicalSize;
use winit::error::EventLoopError;
use winit::event::{Event, WindowEvent};
use winit::event_loop::EventLoop;
use winit::keyboard::Key;
use winit::keyboard::KeyCode;
use winit::window::WindowBuilder;
use winit_input_helper::WinitInputHelper;
const RES: usize = 256;

fn main() -> Result<()> {
    let cli = Cli::parse();
    let initial_state = read_u16s_from_file(&cli.program)?;
    let mut engine = Engine::new(initial_state);

    let event_loop = EventLoop::new()?;
    let mut input = WinitInputHelper::new();
    let window = {
        let size = LogicalSize::new(
            (RES as u32 * cli.scaling) as f64,
            (RES as u32 * cli.scaling) as f64,
        );
        let min_size = LogicalSize::new((RES) as f64, (RES) as f64);
        WindowBuilder::new()
            .with_title("SVC16")
            .with_inner_size(size)
            .with_min_inner_size(min_size)
            .build(&event_loop)?
    };
    let mut pixels = {
        let window_size = window.inner_size();
        let surface_texture = SurfaceTexture::new(window_size.width, window_size.height, &window);
        Pixels::new(RES as u32, RES as u32, surface_texture)?
    };
    let res = event_loop.run(|event, elwt| {
        // Draw the current frame
        if let Event::WindowEvent {
            event: WindowEvent::RedrawRequested,
            ..
        } = event
        {
            // world.draw(pixels.frame_mut());
            if let Err(_) = pixels.render() {
                elwt.exit();
                return;
            }
        }

        // Handle input events
        if input.update(&event) {
            // Close events
            if input.key_pressed(KeyCode::Escape) || input.close_requested() {
                elwt.exit();
                return;
            }

            // Resize the window
            if let Some(size) = input.window_resized() {
                if let Err(_) = pixels.resize_surface(size.width, size.height) {
                    elwt.exit();
                    return;
                }
            }

            // Update internal state and request a redraw
            // world.update();
            while !engine.wants_to_sync() {
                engine.step().unwrap();
            }
            let (c1, c2) = get_input_code(&input).unwrap();
            let nb = engine.perform_sync(c1, c2);
            update_image_buffer(pixels.frame_mut(), &nb);

            window.request_redraw();
        }
    });

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

fn rgb565_to_argb(rgb565: u16) -> (u8, u8, u8) {
    let r = ((rgb565 >> 11) & 0x1F) as u8;
    let g = ((rgb565 >> 5) & 0x3F) as u8;
    let b = (rgb565 & 0x1F) as u8;
    let r = (r << 3) | (r >> 2);
    let g = (g << 2) | (g >> 4);
    let b = (b << 3) | (b >> 2);
    (r, g, b)
    // (0xFF << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
}

fn update_image_buffer(imbuff: &mut [u8], screen: &[u16; RES * RES]) {
    for i in 0..RES * RES {
        let col = rgb565_to_argb(screen[i]);
        *imbuff.get_mut(4 * i).expect("Error with image buffer") = col.0;
        *imbuff.get_mut(4 * i + 1).expect("Error with image buffer") = col.1;
        *imbuff.get_mut(4 * i + 2).expect("Error with image buffer") = col.2;
        *imbuff.get_mut(4 * i + 3).expect("Error with image buffer") = 255;
    }
}

fn get_input_code(input: &WinitInputHelper) -> Result<(u16, u16)> {
    let mp = input.cursor().unwrap_or((0., 0.));
    // let mp = (100., 100.);
    dbg!(mp);
    let pos_code = (mp.1 as u16 * 256) + mp.0 as u16;
    let mut key_code = 0_u16;
    if input.key_pressed(KeyCode::Space) || input.mouse_pressed(winit::event::MouseButton::Left) {
        key_code += 1;
    }
    // if window.get_mouse_down(minifb::MouseButton::Left) || window.is_key_down(Key::Space) {
    //     key_code += 1;
    // }
    // if window.get_mouse_down(minifb::MouseButton::Right) || window.is_key_down(Key::B) {
    //     key_code += 2;
    // }
    // if window.is_key_down(Key::Up) || window.is_key_down(Key::W) {
    //     key_code += 4;
    // }
    // if window.is_key_down(Key::Down) || window.is_key_down(Key::S) {
    //     key_code += 8;
    // }
    // if window.is_key_down(Key::Left) || window.is_key_down(Key::A) {
    //     key_code += 16;
    // }
    // if window.is_key_down(Key::Right) || window.is_key_down(Key::D) {
    //     key_code += 32;
    // }
    // if window.is_key_down(Key::N) {
    //     key_code += 64;
    // }
    // if window.is_key_down(Key::M) {
    //     key_code += 128;
    // }

    // todo!();
    Ok((pos_code, key_code))
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
