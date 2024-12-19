mod cli;
mod engine;
mod utils;

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use cli::Cli;
use engine::Engine;
use pixels::{Error, Pixels, SurfaceTexture};
use std::time::Instant;
use utils::*;
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
            let (c1, c2) = get_input_code(&input, &pixels).unwrap();
            let nb = engine.perform_sync(c1, c2);
            update_image_buffer(pixels.frame_mut(), &nb);

            window.request_redraw();
        }
    });

    Ok(())
}
