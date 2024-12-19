use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    pub program: String,

    #[arg(short, long, default_value = "1", help = "Set the window scaling")]
    pub scaling: u32,

    #[arg(
        short,
        long,
        default_value = "3000000",
        help = "Set the maximum instructions per frame"
    )]
    pub max_ipf: usize,

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
        help = "Output instructions and value at the given address"
    )]
    pub debug: Option<Vec<u16>>,
    #[arg(short, long, help = "Show cursor on window")]
    pub cursor: bool,
}
