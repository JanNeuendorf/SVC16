mod cli;
mod engine;
mod utils;

use anyhow::{anyhow, Result};
use clap::Parser;
use cli::Cli;
use engine::Engine;
use pixels::{Pixels, SurfaceTexture};
use std::time::{Duration, Instant};
use utils::*;
use winit::dpi::LogicalSize;
use winit::event_loop::EventLoop;
use winit::keyboard::KeyCode;
use winit::window::WindowBuilder;
use winit_input_helper::WinitInputHelper;
const RES: usize = 256;
const FRAMETIME: Duration = Duration::from_nanos((1000000000. / 30.) as u64);

fn main() -> Result<()> {
    let cli = Cli::parse();
    let initial_state = read_u16s_from_file(&cli.program)?;
    let mut engine = Engine::new(initial_state);

    let event_loop = EventLoop::new()?;
    let mut input = WinitInputHelper::new();
    if cli.scaling < 1 {
        return Err(anyhow!("The minimal scaling factor is 1"));
    }
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
    window.set_cursor_visible(cli.cursor);
    if cli.fullscreen {
        window.set_fullscreen(Some(winit::window::Fullscreen::Borderless(None)));
    }
    let mut pixels = {
        let window_size = window.inner_size();
        let surface_texture = SurfaceTexture::new(window_size.width, window_size.height, &window);
        Pixels::new(RES as u32, RES as u32, surface_texture)?
    };

    event_loop.run(|event, elwt| {
        let start_time = Instant::now();
        if input.update(&event) {
            if input.key_pressed(KeyCode::Escape) || input.close_requested() {
                elwt.exit();
                return;
            }

            if let Some(size) = input.window_resized() {
                if let Err(_) = pixels.resize_surface(size.width, size.height) {
                    handle_event_loop_error(&elwt, "Resize error");
                    return;
                }
            }

            let mut ipf = 0;
            while !engine.wants_to_sync() && ipf <= cli.max_ipf {
                match engine.step() {
                    Err(_) => {
                        handle_event_loop_error(&elwt, "Invalid operation");
                        return;
                    }
                    _ => {}
                }
                ipf += 1;
            }
            let (c1, c2) = get_input_code(&input, &pixels);
            let nb = engine.perform_sync(c1, c2);
            update_image_buffer(pixels.frame_mut(), &nb);

            let elapsed = start_time.elapsed();
            if cli.verbose {
                println!("Instructions: {} Frametime: {}ms", ipf, elapsed.as_millis());
            }
            if elapsed < FRAMETIME {
                std::thread::sleep(FRAMETIME - elapsed);
            }
            window.request_redraw();
            match pixels.render() {
                Err(_) => {
                    handle_event_loop_error(&elwt, "Rendering error");
                    return;
                }
                _ => {}
            };
        }
    })?;

    Ok(())
}
