alejandra .
cp /etc/nixos/hardware-configuration.nix .
git add hardware-configuration.nix
git add pc

sudo nixos-rebuild switch --install-bootloader --flake .#nixos &&
home-manager switch --flake . &&

git rm hardware-configuration.nix --cached &&
git rm pc --cached &&
rm hardware-configuration.nix &&
lazygit
