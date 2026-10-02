// Shared by the window open/close shaders: a quick take on sandlock's look
// (github:Macs1324/sandlock). On close the window comes apart into a fine
// dust of its own pixels that drifts a little and fades; on open that dust
// flies home, as sandlock's grains do on unlock, and settles on the exact
// pixels. Distances are logical pixels.

const float SL_GRAIN = 2.0;   // grain size
const float SL_SPREAD = 26.0; // how far the dust drifts outwards
const float SL_SWIRL = 20.0;  // how far it curls
const float SL_STAGGER = 0.4; // how unevenly the window comes apart

float sl_hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Value noise and its gradient.
vec3 sl_noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
    float a = sl_hash(i);
    float b = sl_hash(i + vec2(1.0, 0.0));
    float c = sl_hash(i + vec2(0.0, 1.0));
    float d = sl_hash(i + vec2(1.0, 1.0));
    float k4 = a - b - c + d;
    return vec3(a + (b - a) * u.x + (c - a) * u.y + k4 * u.x * u.y,
                du * vec2(b - a + k4 * u.y, c - a + k4 * u.x));
}

// How far the sand at `home` has come apart (0 whole, 1 gone) when the
// effect is `t` of the way through. Patches go at different moments.
float sl_local(vec2 home, float t) {
    vec2 seed = vec2(niri_random_seed * 61.0, niri_random_seed * 23.0);
    float delay = SL_STAGGER * sl_noise(home / 140.0 + seed).x;
    return clamp((t - delay) / (1.0 - SL_STAGGER), 0.0, 1.0);
}

// Where the sand at `home` has drifted to, relative to home. Everything in
// it is smooth, so it can be inverted below.
vec2 sl_drift(vec2 home, vec2 size, float t) {
    vec2 seed = vec2(niri_random_seed * 17.0, niri_random_seed * 79.0);
    float s = sl_local(home, t);
    s = 1.0 - (1.0 - s) * (1.0 - s); // grains start fast and settle
    vec2 outwards = (home - 0.5 * size) / (0.5 * max(size.x, size.y));
    vec3 n = sl_noise(home / 90.0 + seed);
    vec2 curl = vec2(n.z, -n.y) * 0.5;
    return (outwards * SL_SPREAD + curl * SL_SWIRL) * s;
}

// The colour at `coords_geo` when the window is `t` of the way to dust.
// Every grain keeps its own offset, size and moment to fade for the whole
// animation, so the dust moves smoothly instead of shimmering frame to frame.
vec4 sl_dust(vec3 coords_geo, vec3 size_geo, float t) {
    vec2 size = size_geo.xy;
    vec2 px = coords_geo.xy * size;

    // Find the sand that drifted here; the drift is small and smooth, so a
    // few fixed-point steps converge.
    vec2 home = px;
    for (int i = 0; i < 4; i++) {
        home = px - sl_drift(home, size, t);
    }
    float s = sl_local(home, t);

    vec4 whole = vec4(0.0);
    vec2 uv = home / size;
    if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
        whole = texture2D(niri_tex, (niri_geo_to_tex * vec3(uv, 1.0)).st);
    }
    if (s <= 0.0) {
        return whole;
    }

    // The grains around here, each a soft dot drawn at its own position.
    // Neighbouring grains share nearly the same drift, so only their own
    // offsets differ.
    vec4 sand = vec4(0.0);
    float cover = 0.0;
    vec2 cell = floor(home / SL_GRAIN);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 c = cell + vec2(float(x), float(y));
            vec2 centre = (c + 0.5) * SL_GRAIN;
            vec2 grain_uv = centre / size;
            if (any(lessThan(grain_uv, vec2(0.0))) || any(greaterThan(grain_uv, vec2(1.0)))) {
                continue;
            }
            vec2 offset = vec2(sl_hash(c), sl_hash(c + 51.7)) - 0.5;
            vec2 at = centre + offset * 2.0 * SL_GRAIN * s;
            float radius = SL_GRAIN * (0.45 + 0.25 * sl_hash(c + 7.3));
            float dot_ = 1.0 - smoothstep(radius - 0.5, radius + 0.5, length(home - at));
            // Each grain fades over its own stretch of the animation.
            float fade_at = sl_hash(c + 13.1);
            float alive = 1.0 - smoothstep(fade_at * 0.8, fade_at * 0.8 + 0.2, s);
            float w = dot_ * alive;
            sand += w * texture2D(niri_tex, (niri_geo_to_tex * vec3(grain_uv, 1.0)).st);
            cover += w;
        }
    }
    sand /= max(cover, 1.0);

    // The window turns into grains over the first moments of coming apart.
    return mix(whole, sand, smoothstep(0.0, 0.25, s));
}
