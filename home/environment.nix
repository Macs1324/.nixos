{...}: {
  home.sessionVariables = {
    # Set the default editor for the system
    EDITOR = "nvim";
    VISUAL = "nvim";
    GIT_EDITOR = "nvim";

    core = "$HOME/Code/corecf";
    keymaker = "$HOME/Code/corecf/services/keymaker";
    supervisor = "$HOME/Code/uxstream/services/supervisor/supervisor";
    portal = "$HOME/Code/corecf/web/portal";
  };
}
