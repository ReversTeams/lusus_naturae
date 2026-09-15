#version 330

uniform mat4 ModelViewMat;
uniform mat4 ProjMat;
uniform vec2 size;
uniform vec2 scrollOffset;
uniform vec2 scrollSize;
uniform float time;
uniform float zoom;

in vec2 texCoord0;
out vec4 fragColor;

// Noise
uint hash(uint x) {
    x += 0x7EDD5D5u;
    x *= 0xB5297A4Du;
    x ^= (x >> 8u);
    x += 0x1B56C4E9u;
    x ^= (x >> 8u);
    return x;
}
uint hash(uvec2 v) { return hash(v.x ^ hash(v.y)); }
float rand(vec2 v) {
    uint m = hash(uvec2(floatBitsToUint(v.x), floatBitsToUint(v.y)));
    const uint ieeeMantissa = 0x007FFFFFu;
    const uint ieeeOne      = 0x3F800000u;
    m &= ieeeMantissa;
    m |= ieeeOne;
    return uintBitsToFloat(m) - 1.0;
}

// Glitch
vec2 glitchUV(vec2 uv, float t) {
    float shakeAmt = 0.0008;
    vec2 shake = vec2(
        sin(t * 67.0) * shakeAmt + sin(t * 131.0) * shakeAmt * 0.5,
        cos(t * 53.0) * shakeAmt + cos(t * 107.0) * shakeAmt * 0.5
    );

    float jitterTrigger = step(0.97, rand(vec2(floor(t * 6.0), 0.0)));
    float jitterRow = step(0.5, rand(vec2(floor(uv.y * 180.0), floor(t * 6.0))));
    vec2 jitter = vec2(
        (rand(vec2(floor(t * 30.0), floor(uv.y * 180.0))) - 0.5) * 0.02,
        0.0
    ) * jitterTrigger * jitterRow;

    float sliceTrigger = step(0.93, rand(vec2(floor(t * 2.5), 1.0)));
    float sliceBand = step(0.6, rand(vec2(floor(uv.y * 18.0), floor(t * 2.5))));
    vec2 slice = vec2(
        (rand(vec2(floor(t * 4.0), floor(uv.y * 18.0))) - 0.5) * 0.08,
        0.0
    ) * sliceTrigger * sliceBand;

    return uv + shake + jitter + slice;
}

// Grid
float grid(vec2 uv, float t) {
    float cells = 70.0;
    vec2 g = uv * cells;
    vec2 cellId = floor(g);
    vec2 f = fract(g);

    vec2 center = vec2(cells * 0.5);
    
    // Rectangular pulse (Chebyshev distance)
    float d = max(abs(cellId.x - center.x), abs(cellId.y - center.y)) / (cells * 0.5);

    float pulse = sin(d * 18.0 - t * 2.0) * 0.5 + 0.5;
    pulse = pow(pulse, 5.0);

    float edgeX = smoothstep(0.06, 0.0, min(f.x, 1.0 - f.x));
    float edgeY = smoothstep(0.06, 0.0, min(f.y, 1.0 - f.y));
    float lines = max(edgeX, edgeY);

    // Lessened contrast for a more subtle pulse
    return lines * (0.12 + 0.06 * pulse);
}

// Scanlines
float scanlines(vec2 uv, float t) {
    float s = sin(uv.y * size.y * 4.0 + t * 3.0);
    s = smoothstep(0.75, 1.0, s);
    
    // Doubled large animated scanlines, closer together (0.15 offset) and at 25% opacity
    float speed = 0.12;
    float bar1 = smoothstep(0.015, 0.0, abs(uv.y - fract(t * speed)));
    float bar2 = smoothstep(0.015, 0.0, abs(uv.y - fract(t * speed + 0.15)));
    float bar = max(bar1, bar2);
    
    return s * 0.25 + bar * 0.25;
}

// Vignette & glow
float vignette(vec2 uv) {
    vec2 d = uv - 0.5;
    return 1.0 - dot(d, d) * 1.6;
}

// Glitch rectangles
vec3 glitchRects(vec2 uv, float t) {
    vec3 col = vec3(0.0);
    float trigger = step(0.92, rand(vec2(floor(t * 3.0), 2.0)));
    if (trigger < 0.5) return col;

    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float seed = rand(vec2(floor(t * 3.0), fi));
        vec2 p = vec2(rand(vec2(seed, fi)), rand(vec2(fi, seed)));
        vec2 s = vec2(0.05 + rand(vec2(fi, t)) * 0.15,
                      0.01 + rand(vec2(t, fi)) * 0.04);
        vec2 m = step(abs(uv - p), s * 0.5);
        float mask = m.x * m.y;
        vec3 c = (seed > 0.5) ? vec3(1.0, 0.0, 0.0) : vec3(1.0, 0.85, 0.85);
        col += c * mask * 0.7;
    }
    return col;
}

void main() {
    vec2 uv = texCoord0;
    float t = time;

    vec2 guv = glitchUV(uv, t);

    vec3 base = vec3(0.0, 0.0, 0.0);

    float g = grid(guv, t);
    vec3 gridCol = vec3(1.0, 0.15, 0.15) * g;

    float sc = scanlines(guv, t);
    vec3 scanCol = vec3(1.0, 0.2, 0.2) * sc;

    float v = clamp(vignette(guv), 0.0, 1.0);
    vec3 vignetteCol = vec3(0.4, 0.05, 0.05) * (1.0 - v);

    float centerGlow = exp(-length(guv - 0.5) * 4.0);
    float pulseGlow = 0.5 + 0.5 * sin(t * 1.2);
    vec3 glowCol = vec3(1.0, 0.1, 0.1) * centerGlow * 0.25 * pulseGlow;

    vec3 col = base;
    col += gridCol;
    col += scanCol;
    col += vignetteCol;
    col += glowCol;

    col += glitchRects(guv, t);

    // Chromatic aberration
    float caTrigger = step(0.9, rand(vec2(floor(t * 4.0), 3.0)));
    if (caTrigger > 0.5) {
        float off = 0.003;
        float r = grid(guv + vec2(off, 0.0), t);
        float b = grid(guv - vec2(off, 0.0), t);
        col.r += r * 0.2;
        col.b += b * 0.1;
    }

    col = clamp(col, 0.0, 1.0);
    fragColor = vec4(col, 1.0);
}