use macroquad::prelude::*;
pub struct Layout {
    pub x: f32,
    pub y: f32,
    pub size: f32,
}
impl Layout {
    pub fn generate() -> Self {
        let (x, y, size) = place(screen_width(), screen_height());
        Self { x, y, size }
    }
    pub fn clamp_mouse(&self) -> (f32, f32) {
        let (raw_x, raw_y) = mouse_position();
        let clamped_x = (raw_x.clamp(self.x, self.x + self.size) - self.x) / self.size * 255.;
        let clamped_y = (raw_y.clamp(self.y, self.y + self.size) - self.y) / self.size * 255.;
        (clamped_x, clamped_y)
    }
    pub fn cursor_in_window(&self) -> bool {
        let mp = mouse_position();
        mp.0 >= self.x
            && mp.0 < (self.x + self.size)
            && mp.1 >= self.y
            && mp.1 < (self.y + self.size)
    }
}

fn place(width: f32, height: f32) -> (f32, f32, f32) {
    let minsize = width.min(height);
    if minsize >= 256. {
        let image_size = (minsize / 256.).floor() * 256.;
        let startx = (width - image_size) / 2.;
        let starty = (height - image_size) / 2.;
        return (startx, starty, image_size);
    } else {
        let power_two = minsize.log2().floor() as u32;
        let image_size = (2 as usize).pow(power_two) as f32;
        let startx = (width - image_size) / 2.;
        let starty = (height - image_size) / 2.;
        (startx, starty, image_size)
    }
}
