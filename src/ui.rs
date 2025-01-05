use macroquad::prelude::*;
pub struct Layout {
    pub x: f32,
    pub y: f32,
    pub size: f32,
    pub font_y: f32,
    pub font_x: f32,
    pub rect_x: f32,
    pub rect_y: f32,
    pub font_size: f32,
}
impl Layout {
    pub fn generate() -> Self {
        let (width, height) = (screen_width(), screen_height());
        let minsize = width.min(height);
        let image_size = ((minsize / 256.).floor() * 256.).max(256.);
        let x = (0. as f32).max((width - image_size) / 2.);
        let y = (0. as f32).max((height - image_size) / 2.);
        let font_y = y + image_size / 15.;
        Self {
            x,
            y,
            size: image_size,
            font_y,
            font_x: x + 0.01 * image_size,
            rect_x: x + 0.005 * image_size,
            rect_y: y + 0.01 * image_size,
            font_size: image_size / 15.,
        }
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
