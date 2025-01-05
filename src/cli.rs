use clap::Parser;
use macroquad::texture::FilterMode;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[arg(help = "(Decompressed if it ends in .gz)")]
    pub program: String,

    #[arg(short, long, default_value = "1", help = "Set initial window scaling")]
    pub scaling: i32,

    #[arg(
        short,
        long,
        default_value_t = false,
        help = "Show cursor on the window"
    )]
    pub cursor: bool,
    #[arg(
        short,
        long,
        default_value_t = false,
        help = "Start in fullscreen mode"
    )]
    pub fullscreen: bool,
    #[arg(
        short,
        long,
        default_value_t = false,
        help = "Output performance metrics"
    )]
    pub verbose: bool,
    #[arg(long, short, default_value_t = false, help = "Filter")]
    pub linear_filtering: bool,
}
