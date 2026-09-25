# NixOS workstations

A single flake that configures three machines: NixOS for the system and a
standalone Home Manager generation for the `macs` user. Both share one pinned
`nixpkgs`, one theme (Stylix, generated from the wallpaper), and two Wayland
sessions (Hyprland and Niri) with Noctalia as the shell for both.

| Host | Role | Notable hardware |
| --- | --- | --- |
| `workdesktop` | Work, development | Intel Arc B60 (latest kernel, Xe force-probe), two monitors |
| `worklaptop` | Work, development | Laptop panel `eDP-1` |
| `homedesktop` | Development and gaming | AMD GPU with ROCm, Steam, two monitors |

## Layout

```
flake.nix               inputs and the named system/home outputs
hosts/<host>/
  default.nix           system profile: imports, hostname, GPU settings
  hardware-configuration.nix   generated on that machine (see Setup)
  home.nix              home profile for that host
  monitors.nix          monitor and wallpaper inventory
system/                 shared NixOS modules
  base.nix              boot, locale, user, Nix settings and housekeeping
  desktop.nix           SDDM, audio, portals, Hyprland, Niri, Flatpak
  development.nix       languages, Podman, PostgreSQL, sysctl
  work.nix              development.nix plus work-only packages
  games.nix             Steam, controllers, media apps
home/                   shared Home Manager modules
  hyprland.nix/.lua     Hyprland settings and Lua actions
  niri.nix              Niri settings and extra rules
  monitors.nix          feeds the monitor inventory to Niri, Hyprland, Noctalia
  secrets.nix           installs decrypted SSH fragments
  nvim/                 Nixvim configuration
modules/                option definitions: desktop.monitors, desktop.apps
lib/                    monitor translation and the shared nixpkgs policy
secrets/                git-crypt encrypted files
scripts/, tests/        build helpers and their tests
```

Roles are plain imports: a host pulls in `system/work.nix` or `system/games.nix`
as needed. There is no feature-flag layer.

## Setup

### First switch on a machine

1. Clone the repository and unlock secrets (see [Secrets](#secrets)). A locked
   checkout still builds; only the work SSH hosts are missing.
2. Generate and stage the machine's hardware file:

   ```sh
   just hardware workdesktop      # or worklaptop / homedesktop
   ```

   This runs `nixos-generate-config --show-hardware-config`, writes
   `hosts/<host>/hardware-configuration.nix`, and stages it. Nothing is
   committed. Review the diff, then commit it so other machines can build this
   host too.
3. Build, then switch:

   ```sh
   just build workdesktop
   just switch workdesktop
   ```

The first Home Manager switch takes over files it manages. Unmanaged originals
are kept with an `.hm-backup` suffix rather than aborting the switch. In
particular, an existing `~/.ssh/config` becomes `~/.ssh/config.hm-backup`; move
any hosts you want to keep into `~/.ssh/config.local`, which the generated
config includes.

### Host selection

`just` recipes pick the host in this order:

1. Explicit argument: `just switch workdesktop`
2. The `NIXOS_HOST` environment variable
3. The current hostname

Plain `just` switches both system and home for the selected host. Unknown names
are rejected before anything runs.

## Daily use

```sh
just              # build system and home, activate system, then home
just build        # build both without activating
just home         # activate only Home Manager
just check        # formatting, shell checks, tests, evaluate every output
just fmt          # alejandra
just update       # update flake.lock; review, then build and switch yourself
just clean        # full garbage collection now
```

`just switch` builds both halves before activating either. System and home are
still two activations: if the home step fails, the new system is already live.
Fix the issue and run `just home`.

Direct equivalents, if you need them:

```sh
sudo nixos-rebuild switch --flake .#workdesktop
home-manager switch -b hm-backup --flake '.#macs@workdesktop'
```

The system garbage-collects weekly (generations older than 14 days) and
deduplicates the store. `nix shell nixpkgs#foo` and `<nixpkgs>` resolve to the
flake's pinned revision.

## Customizing

### Displays and wallpapers

Each host lists its outputs in `hosts/<host>/monitors.nix`, keyed by connector:

```nix
{
  DP-1 = {
    primary = true;
    mode = { width = 3440; height = 1440; refresh = 165; };
    position = { x = 0; y = 0; };
    wallpaper = ../../assets/wallpapers/forest-sunset.png;
    hyprlandWorkspaces = [ "1" ];
  };
  HDMI-A-2 = {
    mode = { width = 2560; height = 1440; refresh = 144; };
    position = { x = 3440; y = 0; };
    wallpaper = ../../assets/wallpapers/night-mountains.png;
  };
}
```

One inventory drives Niri outputs, Hyprland monitor and workspace rules, and
Noctalia's per-monitor wallpapers. Rules:

- Exactly one enabled output is `primary` and has a wallpaper; others inherit it
  when they omit `wallpaper`.
- `mode` and `position` are optional (preferred mode, automatic placement).
  Positions are logical pixels after `scale` and `rotation`.
- `rotation` is 0/90/180/270 and `flipped` defaults to false. Set
  `enable = false` to turn an output off. Outputs not listed keep compositor
  defaults, so docking does not require listing every screen.
- `hyprlandWorkspaces` is Hyprland-only; Niri's workspaces are dynamic.

Wallpapers live in `assets/wallpapers/` and are named after their content so any
host can use any image. Noctalia's GUI can change wallpapers between switches;
by default each Home Manager switch restores the declared ones, touching only
the wallpaper keys and backing up the state file once. Set
`desktop.wallpapers.resetOverridesOnSwitch = false;` in a host's `home.nix` to
let GUI choices persist.

### Application commands

`desktop.apps` in `modules/apps.nix` holds the shell commands both compositors
and wlogout use:

| Option | Default | Bound to |
| --- | --- | --- |
| `terminal` | `kitty` | `Super+Q` |
| `launcher` | `noctalia msg panel-toggle launcher` | `Super+O` |
| `fileManager` | `thunar` | `Super+E` |
| `lock` | `noctalia msg session lock` | `Ctrl+Alt+L`, wlogout |

Override in a host's `home.nix`, for example `desktop.apps.terminal = "ghostty";`.

### Adding a host

Create `hosts/<name>/` with `default.nix`, `home.nix`, and `monitors.nix`
modeled on an existing host, add the name to the `hosts` list in `flake.nix` and
to the host `case` in both scripts, then run `just hardware <name>` on the
machine.

### Theme

Stylix owns colors, fonts, cursor, and terminal opacity for both NixOS and Home
Manager; per-program color settings are intentionally absent. Both share
`modules/theme.nix`, which generates a dark palette from the wallpaper of the
leftmost enabled output in `hosts/<host>/monitors.nix` (the primary output if no
output has a position). Wallpapers picked in Noctalia's GUI do not change the
palette until they are declared and switched. Apps that Stylix can theme are
configured through Home Manager rather than `environment.systemPackages`:
Discord is Vesktop (`home/discord.nix`) and Spotify is patched by Spicetify
(`home/spotify.nix`), imported per host from `hosts/<host>/home.nix`.
Hyprlock keeps its blurred screenshot background; SDDM keeps its own theme.

## Secrets

Files under `secrets/` are encrypted with git-crypt (`.gitattributes`) and are
plaintext only in an unlocked checkout. The key lives in
`.git/git-crypt/keys/default` and is never committed.

To unlock another machine, export the key from an unlocked checkout and move it
privately:

```sh
git-crypt export-key ~/nixos-git-crypt.key    # unlocked machine
git-crypt unlock ~/nixos-git-crypt.key        # new machine, inside the checkout
```

Currently `secrets/ssh/*.conf` holds work SSH hosts. Home Manager copies
decrypted fragments to `~/.ssh/config.d/` on activation. Ciphertext files are
skipped with a warning, so `ssh` keeps working on a locked checkout.

## Validation

`just check` runs the formatter, shellcheck, the Python helper tests, the
monitor-model tests, and `nix flake check --no-build`, which evaluates every
system with a hardware file and all three home generations. Running
`nix flake check` without `--no-build` also builds the home generations. The
test derivations are exposed as `packages`, so `nix build .#monitor-model` works
without naming a platform.

Evaluation is pure. It catches module and option errors on any machine but
cannot tell whether another host's GPU or disks work; build on the target
before switching.

## Gotchas

- **Hosts without a hardware file are not buildable.** They are omitted from
  `nixosConfigurations`, and `just build`/`just switch` stop with a pointer to
  `just hardware`. Home outputs do not need it.
- **Niri rules that niri-flake cannot express** (`background-effect`) are
  appended as KDL nodes in `home/niri.nix`, on top of the document niri-flake
  renders from `programs.niri.settings`. Add further untyped rules there; the
  result is still validated with `niri validate` at build time.
- **Firewall and PostgreSQL.** The firewall uses NixOS defaults on every host;
  Avahi opens its own ports. Add `networking.firewall.allowedTCPPorts` when a
  development service must be reachable on the LAN. PostgreSQL trusts local
  socket connections and does not listen on TCP.
- **Dunst is present but disabled.** Noctalia owns notifications in both
  sessions; the Dunst settings stay in `home/notifications.nix` for a deliberate
  switch later.
- **Insecure package exceptions** are pinned narrowly in
  `lib/nixpkgs-config.nix` (currently the Electron used by Bitwarden). Expect to
  bump or remove the pin after `just update`.
