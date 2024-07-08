cp /etc/nixos/hardware-configuration.nix .
alejandra .
sudo nixos-rebuild switch --flake .#nixos &&
home-manager switch --flake . &&
lazygit
