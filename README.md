# NixOS workstations

One flake contains three explicit machine profiles. Hardware detection stays on
its respective machine in `/etc/nixos/hardware-configuration.nix`; it is never
copied into this repository or staged during a rebuild. The old `pc` file is
unused and ignored.

| Host | System-specific settings | Home-specific settings |
| --- | --- | --- |
| `workdesktop` | Intel Arc B60, latest kernel, Xe force-probe, development tools | Office monitors and work shortcut |
| `worklaptop` | Default kernel, development tools, Discord | `eDP-1` laptop display and work shortcut |
| `homedesktop` | Default kernel, AMD/ROCm, Steam and gaming applications, development tools | Home monitors |

Development tools remain available on homedesktop, as in the original setup.
Hostnames now match these profile names instead of sharing `nixmacs`.

## Layout

- `flake.nix`: pinned inputs and named system/Home Manager outputs.
- `hosts/<name>/default.nix`: system profile and host-specific GPU settings.
- `hosts/<name>/home.nix`: home profile and host-specific shortcuts.
- `hosts/<name>/monitors.nix`: the single monitor and wallpaper inventory.
- `modules/monitors.nix`: typed monitor options and validation.
- `lib/monitors.nix`: translations to compositor and wallpaper settings.
- `home/monitors.nix`: connects the inventory to the desktop modules.
- `system/`: shared base, hardware, desktop, theme, and packages; explicitly
  imported development and gaming profiles.
- `home/`: shared Home Manager modules for programs, shell, terminals, theme,
  desktop sessions, and editor configuration.
- `lib/nixpkgs-config.nix`: package policy shared by NixOS and standalone Home Manager.
- `scripts/rebuild.sh`: paired build/switch workflow, with no Git mutations.

Nixvim uses native module imports instead of a custom shallow merge. Hyprland
uses Lua, as required by the pinned version; native settings live in
`home/hyprland.nix`, actions in `home/hyprland.lua`, and displays in each host's
monitor inventory. See the [Hyprland configuration documentation](https://wiki.hypr.land/configuring/core/).

## First use after this refactor

Review and add the refactor's files to Git so flake evaluation can see the new
modules. Git-backed flakes exclude untracked files; `pc` and hardware files must
remain ignored. The helper deliberately does not stage or commit anything.

On **each target machine**, check that `/etc/nixos/hardware-configuration.nix`
contains that machine's generated configuration. Keep a separate backup of this
file. If it needs generating, use `sudo nixos-generate-config --show-hardware-config`
and review the result before saving it there.

Choose the host explicitly for the first build and switch, for example:

```sh
just build workdesktop
just switch workdesktop
```

Use `worklaptop` or `homedesktop` on those machines. **Plain `just` switches both
configurations.** Selection follows this order:

1. Explicit argument, such as `just switch workdesktop`.
2. The `NIXOS_HOST` environment variable.
3. The current hostname.

For the first switch on a machine still named `nixmacs`:

```sh
NIXOS_HOST=workdesktop just
```

Afterward, the hostname matches the profile and `just` works without an override.
You can also use `export NIXOS_HOST=workdesktop` in a shell, then run `just`.
No environment value is read by the flake itself: it always exposes all three
named configurations. Unknown host names are rejected before building or switching.
`just build` and `just home` use the same selection order; an explicit argument
wins over an exported variable. Use `just --list` for the recipe list.

`just switch` builds both the system and home generation before activating the
system and then Home Manager. These remain two separate activations; if Home
Manager activation fails, the new system is already active. Fix the home issue
and run `just home <host>`. Builds alone do not activate anything.

Direct equivalents:

```sh
sudo nixos-rebuild switch --impure --flake .#workdesktop
home-manager switch --flake '.#macs@workdesktop'
```

NixOS requires `--impure` solely to import the local `/etc/nixos` hardware file.
Home Manager remains independently evaluable without it. Build system outputs
on their target machine: choosing another profile locally still uses the local
machine's hardware file, so it is not a cross-machine deployment mechanism.

The old `.#nixos` and `.#macs` outputs have been replaced by the explicit names.
Home Manager remains standalone, following its
[flake workflow](https://nix-community.github.io/home-manager/nix-flakes/standalone.html).
Both state versions stay at `24.05`, and this refactor does not update `flake.lock`.

## Maintenance and validation

```sh
just                    # Build and switch the selected system and home
just fmt                # Format Nix files
just check              # Formatting, shell checks, helper tests, all output evaluations
just build              # Build the local system and home without activation
just home               # Activate only Home Manager
just update             # Update the lock file for review
```

`just check` evaluates all three system profiles against **the current machine's**
hardware file, and evaluates all three Home Manager generations. This catches
module errors, but cannot validate another machine's storage or GPU at runtime.
`nix flake check --impure` additionally builds all three Home Manager checks.
`just check` also builds the monitor-model and helper tests, including tests for
wallpaper state preservation and host selection; Python dependencies come from Nix. System
builds are separate (`just build <host>`). Run the build on each actual machine
before switching it. Updating no longer automatically switches, commits, or pushes.

Before staging new files, equivalent local validation can use the explicit
`path:.` flake reference (for example, `nix flake check --impure --no-build path:.`).
This includes untracked files, so ordinary maintenance uses the Git-backed `.`.

## Configure displays once

Edit `hosts/<host>/monitors.nix`. Connector names are the keys:

```nix
{
  DP-1 = {
    primary = true;
    mode = { width = 3440; height = 1440; refresh = 165; };
    scale = 1.0;
    position = { x = 0; y = 0; };
    wallpaper = ../../assets/wallpapers/workdesktop-1.png;
    hyprlandWorkspaces = [ "1" ];
  };
  HDMI-A-2 = {
    mode = { width = 2560; height = 1440; refresh = 144; };
    position = { x = 3440; y = 0; };
    wallpaper = ../../assets/wallpapers/workdesktop-2.png;
  };
}
```

The shared adapter generates:

| Consumer | Generated settings |
| --- | --- |
| Niri | Output modes, scales, positions, rotation, enabled/disabled outputs |
| Hyprland | Equivalent monitor rules and optional workspace assignments |
| Noctalia | Per-monitor wallpapers in both Wayland sessions and the default image |
| GNOME background/screensaver | Primary output's wallpaper as the single-background fallback |

Specify exactly one enabled `primary` output with a wallpaper. `primary` selects
the fallback image; it does not impose compositor-specific focus or bar placement.
Other outputs can omit `wallpaper` to inherit that image. Omit `mode` to use the
preferred resolution/refresh; omit `mode.refresh` to use the compositor's default
refresh for the specified resolution. Omit `position` for automatic placement.
`scale` defaults to 1. Positions are **logical pixels**, accounting for scale and
rotation: a 3840-pixel-wide display at scale 2 occupies 1920 logical pixels.

`rotation` accepts 0, 90, 180, or 270 degrees counter-clockwise; `flipped` defaults
to false. Set `enable = false` to disable a configured output. Unlisted outputs
retain compositor defaults, so docking does not require enumerating every screen.
Use exact connector names, as Noctalia's saved wallpaper paths use those names.

`hyprlandWorkspaces` deliberately stays compositor-specific: Niri's dynamic
workspace model is different. Modules that need display information can read
`config.desktop.monitors`, or call `lib/monitors.nix` for its normalized connector
list, wallpaper map, and generated settings. Add a new consumer in the adapter
without duplicating the machine definitions. Hyprlock keeps its existing
screenshot background.

The initial inventories use the existing per-machine wallpaper assets and Niri's
refresh values, resolving the old small differences between compositor configs.

### Wallpaper ownership

Noctalia's GUI saves overrides that load after its declarative TOML, as described
in its [configuration documentation](https://docs.noctalia.dev/noctalia/configuration/).
By default, every Home Manager switch restores the declared wallpapers:

- The adapter writes the generated settings through Noctalia's Home Manager module,
  which validates the TOML at build time.
- The activation step clears only saved wallpaper paths for declared connectors,
  the default/last wallpaper paths, and the wallpaper enable/automation overrides.
- Other settings, comments, and wallpaper choices for unlisted connectors remain.
- Before the first edit, it backs up the state beside the original file as
  `settings.toml.before-nix-monitors`. Repeated activations do not replace the backup.
- Missing state is left alone, symlinks are preserved, and Home Manager dry runs do
  not edit it. This respects `NOCTALIA_STATE_HOME` and `XDG_STATE_HOME`.

GUI wallpaper changes remain possible between switches. To let them persist
across switches, add this to the machine's `home.nix`:

```nix
desktop.wallpapers.resetOverridesOnSwitch = false;
```

No live settings are edited during evaluation or building; this happens only when
you activate Home Manager. Noctalia watches both configuration layers for changes.

### Further useful abstractions

Good next candidates are shared application commands (terminal, launcher, browser,
file manager, lock action), font/cursor/opacity preferences, and keyboard/touchpad
settings. Each can have small adapters for the consumers that use it. Stylix
already handles much of the theme sharing. Keep compositor-specific window rules,
animations, and workspace behavior in their native modules: their semantics differ
too much for a useful universal model. Work/gaming roles are already expressed as
module imports; add feature options only when machines actually need combinations
that those imports cannot express clearly.

## Behavior fixes and retained policies

- Corrected laptop output `eDP=1` to `eDP-1`.
- Migrated the rejected Hyprlang configuration to Lua, fixed nested settings,
  duplicate `exec-once`, and the notification layer's namespace match.
- Added Hyprlock's PAM service and installed the brightness command used by Niri.
- Disabled Dunst so it does not compete with Noctalia for notification ownership.
  Its settings remain in `home/notifications.nix` for an intentional future switch.
- Removed forced Mesa/Vulkan driver paths and unused legacy Intel drivers from
  the Arc host. Kept its kernel, Xe force-probe, and iHD selection.
- Removed duplicate firmware and driver declarations. Xbox controller support
  belongs to the home gaming profile, and its NixOS module installs its driver.
- Made unfree/insecure package policy consistent between NixOS and Home Manager.
- Moved user environment variables out of the system environment, removed the
  invalid `SHELL=zsh` override, and fixed Alacritty's literal form-feed escape.
- Wallpapers use Nix store paths instead of assuming the checkout is `~/.nixos`.

The existing LAN development firewall policy (`enable = false`) and local
PostgreSQL `trust` authentication remain explicit in `system/development.nix`.
Changing either needs the application's port/authentication requirements;
PostgreSQL is not configured to accept TCP connections here. The existing
Bitwarden Electron exception remains narrowly pinned in `lib/nixpkgs-config.nix`.
