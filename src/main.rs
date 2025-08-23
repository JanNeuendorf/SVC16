mod cli;
mod engine;
mod ui;
mod utils;
#[allow(unused)] // Usage depends on Gamepad feature
use anyhow::{anyhow, Context, Result};
use clap::Parser;
use cli::Cli;
use engine::Engine;
#[cfg(feature = "gamepad")]
use gilrs::Gilrs;
use macroquad::prelude::*;
use std::time::{Duration, Instant};
use ui::Layout;
use utils::*;

use crate::engine::{Extension, NoExtension, RandomExtension, SoundExtension};
const MAX_IPF: usize = 3000000; // Maximum instruction can be changed here for easier testing.
const FRAMETIME: Duration = Duration::from_nanos((1000000000. / 30.) as u64);

fn window_conf() -> Conf {
    // Both the scaling and the fullscreen options are only important for the initial launch of the window.
    // You can still rescale or exit fullscreen mode.
    let cli = Cli::parse();

    Conf {
        window_title: "SVC16".to_owned(),
        window_width: 256 * cli.scaling,
        window_height: 256 * cli.scaling,
        fullscreen: cli.fullscreen,

        ..Default::default()
    }
}
#[macroquad::main(window_conf)]
async fn main() -> Result<()> {
    let mut cli = Cli::parse();
    print_keybinds();

    // This is the raw image data.
    let mut buffer = vec![Color::from_rgba(255, 255, 255, 255); 256 * 256];

    let mut image = Image::gen_image_color(256, 256, Color::from_rgba(0, 0, 0, 255));
    let texture = Texture2D::from_image(&image);

    if cli.linear_filtering {
        texture.set_filter(FilterMode::Linear);
    } else {
        texture.set_filter(FilterMode::Nearest);
    }

    // This is not the screen-buffer itself. It still needs to be synchronized.
    let mut raw_buffer = vec![0u16; 256 * 256];

    let extension: Box<dyn Extension> = match cli.extension {
        cli::ActiveExtension::None => Box::new(NoExtension),
        cli::ActiveExtension::Random => Box::new(RandomExtension),
        cli::ActiveExtension::Sound => Box::new(SoundExtension::new()),
    };
    let mut engine = Engine::new(read_u16s_from_file(&cli.program)?, extension);
    let mut paused = false;
    let mut ipf = 0;

    #[cfg(feature = "gamepad")]
    let mut gilrs = match Gilrs::new() {
        Ok(g) => g,
        _ => return Err(anyhow!("Gamepad could not be loaded")),
    };

    loop {
        let start_time = Instant::now();
        if is_key_pressed(KeyCode::Escape) {
            break;
        }
        if is_key_pressed(KeyCode::P) {
            paused = !paused;
        }
        if is_key_pressed(KeyCode::R) {
            // The current behavior is reloading the file and unpausing.
            engine.reset(read_u16s_from_file(&cli.program)?);
            paused = false;
        }
        if is_key_pressed(KeyCode::V) {
            cli.verbose = !cli.verbose;
        }
        if is_key_pressed(KeyCode::C) {
            cli.cursor = !cli.cursor;
        }
        // The size of the image in the window depends on the filtering.
        // If it is linear, it is as big as it can be.
        // If it is nearest, it is the largest possible integer scaling.
        let layout = Layout::generate(cli.linear_filtering);
        if !paused {
            ipf = 0;
            while !engine.wants_to_sync() && ipf <= MAX_IPF {
                if let Some(debug_output) = engine.step()? {
                    if cli.verbose {
                        println!(
                            "DEBUG label: {} values: {}, {}",
                            debug_output.0, debug_output.1, debug_output.2
                        );
                    }
                }
                ipf += 1;
            }
            #[cfg(feature = "gamepad")]
            while let Some(event) = gilrs.next_event() {
                gilrs.update(&event);
            }
            #[cfg(not(feature = "gamepad"))]
            let (mpos, keycode) = get_input_code_no_gamepad(&layout);

            #[cfg(feature = "gamepad")]
            let (mpos, keycode) = get_input_code_gamepad(&layout, &gilrs);

            engine.perform_sync(mpos, keycode, &mut raw_buffer);
            update_image_buffer(&mut buffer, &raw_buffer);
            image.update(&buffer);
            texture.update(&image);
        }
        clear_background(BLACK);

        if layout.cursor_in_window() {
            show_mouse(cli.cursor);
        } else {
            show_mouse(true); //The cursor is always shown when it is not on the virtual screen.
        }

        draw_texture_ex(
            &texture,
            layout.x,
            layout.y,
            WHITE,
            DrawTextureParams {
                dest_size: Some(vec2(layout.size, layout.size)),

                ..Default::default()
            },
        );
        if cli.verbose {
            // Background of the performance metrics.
            draw_rectangle(
                layout.rect_x,
                layout.rect_y,
                0.25 * layout.size,
                layout.font_size,
                Color::from_rgba(0, 0, 0, 200),
            );

            draw_text(
                &format!("{}", ipf),
                layout.font_x,
                layout.font_y,
                layout.font_size,
                LIME,
            );
        }

        // Wait for the next frame
        let elapsed = start_time.elapsed();
        if elapsed < FRAMETIME {
            std::thread::sleep(FRAMETIME - elapsed);
        } else if cli.verbose {
            // If you see this, the program is running too slow on your PC.
            println!("Frame was not processed in time");
        }
        next_frame().await;
    }
    Ok(())
}
