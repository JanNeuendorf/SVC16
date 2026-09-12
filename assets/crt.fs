#version 330

// Input attributes from Raylib vertex shader
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Uniforms from Raylib
uniform sampler2D texture0;
uniform vec4 colDiffuse;

const float CURVATURE = 0.12;           // Barrel distortion amount (0.0 = flat, 0.25 = heavy curved CRT)
const float SCANLINE_INTENSITY = 0.30;  // Dark scanline strength (0.0 = off, 0.6 = heavy dark lines)
const float SCANLINE_COUNT = 256.0;     // Number of scanlines (matching 256 screen height)
const float VIGNETTE_STRENGTH = 0.20;   // Corner darkening strength (0.0 = off, 0.6 = heavy vignette)
const float CHROMATIC_OFFSET = 0.003;   // Color channel separation 
const float BRIGHTNESS_BOOST = 1.35;    // Brightness compensation for scanlines
const vec4 BEZEL_COLOR = vec4(0.0, 0.0, 0.0, 1.0);  // Background color outside curved screen

vec2 curveUV(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) * vec2(CURVATURE);
    uv = uv + uv * offset * offset;
    return uv * 0.5 + 0.5;
}

void main() {
    vec2 uv = curveUV(fragTexCoord);

    // Out of bounds check for CRT bezel
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        finalColor = BEZEL_COLOR;
        return;
    }

    // Chromatic Aberration 
    float r = texture(texture0, vec2(uv.x - CHROMATIC_OFFSET, uv.y)).r;
    float g = texture(texture0, uv).g;
    float b = texture(texture0, vec2(uv.x + CHROMATIC_OFFSET, uv.y)).b;
    vec3 col = vec3(r, g, b);

    // Scanlines
    float scanline = sin(uv.y * SCANLINE_COUNT * 3.14159265 * 2.0);
    scanline = (1.0 - SCANLINE_INTENSITY) + SCANLINE_INTENSITY * (0.5 + 0.5 * scanline);
    col *= scanline;

    // Vignette (darken corners)
    vec2 v_uv = uv * (1.0 - uv.yx);
    float vig = v_uv.x * v_uv.y * 15.0;
    vig = clamp(pow(vig, VIGNETTE_STRENGTH), 0.0, 1.0);
    col *= vig;

    // Brightness boost to offset scanline dimming
    col *= BRIGHTNESS_BOOST;

    finalColor = vec4(col, 1.0) * fragColor * colDiffuse;
}
