// The dust in reverse: the grains fly home.
vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    return sl_dust(coords_geo, size_geo, 1.0 - niri_clamped_progress);
}
