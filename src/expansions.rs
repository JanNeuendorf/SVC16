use rand::Rng;
use rodio::{OutputStream, Sink, Source};

use crate::engine::MEMSIZE;

pub trait Expansion {
    fn read_ubuff(&mut self, _ubuff: &[u16]) {}
    fn output(&self) -> Box<[u16; MEMSIZE]> {
        Box::new([0_u16; MEMSIZE])
    }
    fn run(&mut self) {}
    fn reset(&mut self) {}
    fn pause(&mut self) {}
    fn resume(&mut self) {}
}
pub struct NoExpansion;
impl Expansion for NoExpansion {}

pub struct RandomExpansion;
impl Expansion for RandomExpansion {
    fn output(&self) -> Box<[u16; MEMSIZE]> {
        let mut rng = rand::rng();
        let r = [0; MEMSIZE].map(|_| rng.random::<u16>());
        Box::new(r)
    }
}

pub struct Source16 {
    samples: std::vec::IntoIter<f32>,
}
impl Iterator for Source16 {
    type Item = f32;

    fn next(&mut self) -> Option<Self::Item> {
        self.samples.next()
    }
}
impl Source for Source16 {
    fn current_span_len(&self) -> Option<usize> {
        None
    }

    fn channels(&self) -> rodio::ChannelCount {
        1
    }

    fn sample_rate(&self) -> rodio::SampleRate {
        16000
    }

    fn total_duration(&self) -> Option<std::time::Duration> {
        None
    }
}

impl Source16 {
    fn new(input: &[u16]) -> Self {
        let mut v = vec![];
        for u in input {
            let i = i16::from_ne_bytes(u.to_ne_bytes());
            let f = ((i as f32) / (32_768.0)).clamp(-1., 1.);
            v.push(f)
        }
        Self {
            samples: v.into_iter(),
        }
    }
}
pub struct SoundExpansion {
    stream: OutputStream,
    samples: Vec<u16>,
    sinks: Vec<Sink>,
}
impl SoundExpansion {
    pub fn new() -> Self {
        let mut stream = rodio::OutputStreamBuilder::open_default_stream()
            .expect("could not open default audio stream");
        stream.log_on_drop(false);
        Self {
            stream,
            samples: vec![],
            sinks: vec![],
        }
    }
}
impl Expansion for SoundExpansion {
    fn read_ubuff(&mut self, _ubuff: &[u16]) {
        self.samples = _ubuff.to_vec();
    }

    fn output(&self) -> Box<[u16; MEMSIZE]> {
        Box::new([0_u16; MEMSIZE])
    }

    fn run(&mut self) {
        #[allow(clippy::all)]
        let sink = rodio::Sink::connect_new(&self.stream.mixer());
        sink.append(Source16::new(&self.samples));
        self.sinks.push(sink);
    }

    fn reset(&mut self) {
        *self = Self::new()
    }

    fn pause(&mut self) {
        for s in &self.sinks {
            s.pause();
        }
    }

    fn resume(&mut self) {
        for s in &self.sinks {
            s.play();
        }
    }
}
