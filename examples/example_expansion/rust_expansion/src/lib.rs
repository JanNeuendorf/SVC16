use std::sync::{LazyLock, Mutex};

const MEMSIZE: usize = 2usize.pow(16);

static EXPANSION: LazyLock<Mutex<Expansion>> = LazyLock::new(|| Mutex::new(Expansion));

#[unsafe(no_mangle)]
pub unsafe extern "C" fn svc16_expansion_api_version() -> usize {
    1
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn svc16_expansion_on_init() {
    EXPANSION
        .lock()
        .expect("failed to lock global expansion struct")
        .on_init();
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn svc16_expansion_on_deinit() {
    EXPANSION
        .lock()
        .expect("failed to lock global expansion struct")
        .on_deinit();
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn svc16_expansion_triggered(buffer: &mut [u16; MEMSIZE]) {
    EXPANSION
        .lock()
        .expect("failed to lock global expansion struct")
        .on_expansion_triggered(buffer);
}

struct Expansion;
impl Expansion {
    fn on_init(&mut self) {}
    fn on_deinit(&mut self) {}
    fn on_expansion_triggered(&mut self, buffer: &mut [u16; MEMSIZE]) {
        buffer[0] = b'H' as u16;
        buffer[1] = b'e' as u16;
        buffer[2] = b'l' as u16;
        buffer[3] = b'l' as u16;
        buffer[4] = b'o' as u16;
    }
}
