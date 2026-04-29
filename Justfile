default:
	just switch
	lazygit

update:
	sudo nix flake update
	just switch
	git add flake.lock
	git commit -m "update"
	git push

switch:
	alejandra .
	cp /etc/nixos/hardware-configuration.nix .
	git add hardware-configuration.nix
	git add pc

	sudo nixos-rebuild switch --install-bootloader --flake .#nixos && home-manager switch --flake . && git rm hardware-configuration.nix --cached && git rm pc --cached && rm hardware-configuration.nix

clean:
	sudo nix-collect-garbage -d
	nix-collect-garbage -d
