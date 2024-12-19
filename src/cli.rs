use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    pub program: String,

    #[arg(short, long, default_value = "1", help = "Set initial window scaling")]
    pub scaling: u32,

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
    #[arg(
        short,
        long,
        default_value = "3000000",
        help = "Change the maximum instructions per frame"
    )]
    pub max_ipf: usize,
}
