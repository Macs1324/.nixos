vec4 close_color(vec3 coords_geo, vec3 size_geo) {
    return sl_dust(coords_geo, size_geo, niri_clamped_progress);
}
