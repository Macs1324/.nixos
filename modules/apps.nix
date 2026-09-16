{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  app = default: description:
    mkOption {
      inherit default description;
      type = types.str;
    };
in {
  options.desktop.apps = {
    terminal = app "kitty" "Shell command that opens the terminal.";
    launcher = app "noctalia msg panel-toggle launcher" "Shell command that opens the application launcher.";
    fileManager = app "thunar" "Shell command that opens the file manager.";
    lock = app "hyprlock" "Shell command that locks the session.";
  };

  config.assertions = [
    {
      assertion = lib.all (command: command != "") (lib.attrValues config.desktop.apps);
      message = "desktop.apps commands must not be empty.";
    }
  ];
}
