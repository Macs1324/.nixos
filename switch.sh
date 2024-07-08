cp /etc/nixos/hardware-configuration.nix .
sudo nixos-rebuild switch --flake .#nixos &&
home-manager switch --flake . &&
lazygit
