mod cli;
mod engine;
mod ui;
mod utils;

use anyhow::Result;
use clap::Parser;
use cli::Cli;
use engine::Engine;
#[cfg(feature = "gamepad")]
use gilrs::Gilrs;
use macroquad::prelude::*;
use std::time::{Duration, Instant};
use ui::Layout;
use utils::*;
const MAX_IPF: usize = 3000000;
const FRAMETIME: Duration = Duration::from_nanos((1000000000. / 30.) as u64);

fn window_conf() -> Conf {
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
    let cli = Cli::parse();
    // show_mouse(cli.cursor);

    let mut buffer = [Color::from_rgba(255, 255, 255, 255); 256 * 256];
    let texture = Texture2D::from_image(&Image::gen_image_color(256, 256, BLACK));
    texture.set_filter(FilterMode::Nearest);

    let mut image = Image::gen_image_color(256, 256, Color::from_rgba(0, 0, 0, 255));
    let mut raw_buffer = [0 as u16; 256 * 256];
    let initial_state = read_u16s_from_file(&cli.program)?;
    let mut engine = Engine::new(initial_state.clone());
    let mut paused = false;

    loop {
        let start_time = Instant::now();
        if is_key_pressed(KeyCode::Escape) {
            break;
        }
        if is_key_pressed(KeyCode::P) {
            paused = !paused;
        }
        if is_key_pressed(KeyCode::R) {
            engine = Engine::new(initial_state.clone());
            paused = false;
        }

        let mut ipf = 0;
        let engine_start = Instant::now();
        while !engine.wants_to_sync() && ipf <= MAX_IPF && !paused {
            engine.step()?;
            ipf += 1;
        }

        let _engine_elapsed = engine_start.elapsed();
        let (mpos, keycode) = get_input_code();
        engine.perform_sync(mpos, keycode, &mut raw_buffer);
        update_image_buffer(&mut buffer, &raw_buffer);
        image.update(&buffer);
        texture.update(&image);
        clear_background(BLACK);
        let layout = Layout::generate();
        if layout.cursor_in_window() {
            show_mouse(cli.cursor);
        } else {
            show_mouse(true);
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

        // Wait for the next frame
        let elapsed = start_time.elapsed();
        if elapsed < FRAMETIME {
            std::thread::sleep(FRAMETIME - elapsed);
        }
        next_frame().await;
    }
    Ok(())
}
