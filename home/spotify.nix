{...}: {
  # Spicetify patches the Spotify client so Stylix can theme it. A Spotify update
  # in nixpkgs can break the patch until spicetify-nix catches up.
  programs.spicetify.enable = true;
}
