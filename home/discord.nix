{...}: {
  # Vesktop instead of the official client: Stylix can theme it through Vencord,
  # and Wayland screen sharing with audio works.
  # Stylix writes Vencord's settings file, so plugin toggles made in the app do
  # not persist; declare them in programs.vesktop.vencord.settings instead.
  programs.vesktop.enable = true;
}
