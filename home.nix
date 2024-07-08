{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "macs";
  home.homeDirectory = "/home/macs";

  wayland = {
	windowManager.hyprland = {
		enable = true;
		settings = {
			"$mod" = "SUPER";
			bind = [
				"$mod, Q, exec, kitty"
			]
			++ (
			# workspaces
			# binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
			builtins.concatLists (builtins.genList (
			    x: let
			      ws = let
				c = (x + 1) / 10;
			      in
				builtins.toString (x + 1 - (c * 10));
			    in [
			      "$mod, ${ws}, workspace, ${toString (x + 1)}"
			      "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
			    ]
			  )
			  10)
		      );
			bindm = [
			    # mouse movements
			    "$mod, mouse:272, movewindow"
			    "$mod, mouse:273, resizewindow"
			    "$mod ALT, mouse:272, resizewindow"
			];
		};
	};
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
