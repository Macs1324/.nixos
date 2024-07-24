alejandra .
cp /etc/nixos/hardware-configuration.nix .
git add hardware-configuration.nix

sudo nixos-rebuild switch --flake .#nixos &&
home-manager switch --flake . &&

git rm hardware-configuration.nix
lazygit
