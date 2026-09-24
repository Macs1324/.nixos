{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ai.claude;
  work = cfg.profile == "work";

  # Formats a file Claude just wrote. Only alejandra and jq are hard deps;
  # every other formatter is used when the project already provides it, so
  # this never fails a tool call over a missing binary.
  formatHook = pkgs.writeShellApplication {
    name = "claude-format-hook";
    runtimeInputs = [
      pkgs.jq
      pkgs.alejandra
    ];
    text = ''
      f=$(jq -r '.tool_input.file_path // empty')
      [ -n "$f" ] && [ -f "$f" ] || exit 0
      case "$f" in
        *.nix) alejandra -q "$f" ;;
        *.rs) command -v rustfmt >/dev/null && rustfmt --edition 2021 "$f" ;;
        *.go) command -v gofmt >/dev/null && gofmt -w "$f" ;;
        *.py) command -v ruff >/dev/null && ruff format -q "$f" ;;
        *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.css)
          if command -v biome >/dev/null; then biome format --write "$f" >/dev/null
          elif command -v prettier >/dev/null; then prettier --log-level silent --write "$f"
          fi ;;
      esac
      exit 0
    '';
  };

  statusLine = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
    ];
    text = ''
      input=$(cat)
      model=$(jq -r '.model.display_name' <<<"$input")
      dir=$(jq -r '.workspace.current_dir' <<<"$input")
      used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
      branch=$(git -C "$dir" branch --show-current 2>/dev/null || true)
      printf '%s' "[$model] $(basename "$dir")"
      [ -n "$branch" ] && printf ' (%s)' "$branch"
      [ -n "$used" ] && printf ' ctx:%s%%' "$used"
      printf ' [${cfg.profile}]'
    '';
  };

  # Commands that only read state. Approved everywhere so routine
  # investigation never prompts.
  readOnlyCommands = [
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git blame:*)"
    "Bash(ls:*)"
    "Bash(tree:*)"
    "Bash(jq:*)"
    "Bash(nix eval:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"
    "Bash(nix flake check:*)"
    "Bash(nix build:*)"
    "Bash(nix search:*)"
    "Bash(alejandra --check:*)"
    "Bash(just check:*)"
    "Bash(just build:*)"
    "Bash(cargo check:*)"
    "Bash(cargo clippy:*)"
    "Bash(cargo test:*)"
    "Bash(cargo fmt:*)"
    "Bash(go test:*)"
    "Bash(go vet:*)"
    "Bash(npm test:*)"
    "Bash(npm run lint:*)"
    "Bash(npm run typecheck:*)"
  ];

  # Extra latitude for experimentation: anything that only touches the
  # working tree or a local toolchain.
  vibeCommands = [
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git checkout:*)"
    "Bash(git switch:*)"
    "Bash(git stash:*)"
    "Bash(cargo:*)"
    "Bash(go:*)"
    "Bash(npm:*)"
    "Bash(npx:*)"
    "Bash(bun:*)"
    "Bash(python:*)"
    "Bash(uv:*)"
    "Bash(just:*)"
    "Bash(nix develop:*)"
    "Bash(nix shell:*)"
    "Bash(nix run:*)"
    "Bash(mkdir:*)"
    "Bash(touch:*)"
    "Bash(cp:*)"
    "Bash(mv:*)"
    "WebFetch"
    "WebSearch"
  ];

  denied = [
    "Read(**/.env)"
    "Read(**/.env.*)"
    "Read(**/secrets/**)"
    "Read(~/.ssh/**)"
    "Read(~/.gnupg/**)"
    "Bash(git push --force:*)"
    "Bash(git push -f:*)"
    "Bash(git push --force-with-lease:*)"
    "Bash(git reset --hard:*)"
    "Bash(rm -rf /:*)"
    "Bash(rm -rf ~:*)"
  ]
  ++ lib.optionals work [
    "Read(~/.aws/**)"
    "Read(~/.kube/**)"
    "Read(~/.config/gcloud/**)"
    "Read(~/.docker/config.json)"
    "Bash(git push:*)"
  ];

  mdDir =
    dir:
    lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".md" file) (dir + "/${file}")) (
      lib.filterAttrs (f: t: t == "regular" && lib.hasSuffix ".md" f) (builtins.readDir dir)
    );
in
{
  options.ai.claude.profile = lib.mkOption {
    type = lib.types.enum [
      "work"
      "personal"
    ];
    default = "work";
    description = ''
      work: every write is approved, pushes are always manual, bypass mode is
      locked out, credential directories are unreadable.
      personal: edits and local toolchain commands run unprompted; `vibe`
      drops all prompts for throwaway experiments.
    '';
  };

  config = {
    # Shared with programs.opencode via its enableMcpIntegration.
    programs.mcp = {
      enable = true;
      servers = {
        nixos = {
          command = lib.getExe pkgs.mcp-nixos;
        };
        context7 = {
          command = lib.getExe pkgs.context7-mcp;
        };
      };
    };

    programs.claude-code = {
      enable = true;
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      enableMcpIntegration = true;

      settings = {
        env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        model = "claude-opus-5-5[1m]";
        alwaysThinkingEnabled = true;
        tui = "fullscreen";
        agentPushNotifEnabled = true;
        enabledPlugins."rust-analyzer-lsp@claude-plugins-official" = true;

        permissions = {
          defaultMode = if work then "default" else "acceptEdits";
          allow = readOnlyCommands ++ lib.optionals (!work) vibeCommands;
          deny = denied;
          disableBypassPermissionsMode = lib.mkIf work "disable";
        };

        hooks.PostToolUse = [
          {
            matcher = "Edit|Write";
            hooks = [
              {
                type = "command";
                command = lib.getExe formatHook;
              }
            ];
          }
        ];

        statusLine = {
          type = "command";
          command = lib.getExe statusLine;
          padding = 0;
        };

        cleanupPeriodDays = if work then 30 else 90;
      };

      context = ./CLAUDE.md;
      agents = mdDir ./agents;
      commands = mdDir ./commands;
      rules = mdDir ./rules;
    };

    programs.zsh.shellAliases =
      if work then
        {
          # Bypass mode is disabled on work hosts; this is as loose as it gets.
          vibe = "claude --permission-mode acceptEdits";
        }
      else
        {
          vibe = "claude --dangerously-skip-permissions";
        };
  };
}
