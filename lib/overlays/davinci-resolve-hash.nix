# Blackmagic re-uploaded the DaVinci Resolve 21.1 zip in place (the download now
# serves v21.1-1), so the source hash nixpkgs pinned on 2026-09-09 no longer
# matches what the fetcher gets and the build fails before it starts.
#
# The package bakes its inner derivation into an FHS wrapper, so there is no
# `override` that reaches the hash; instead re-call the upstream expression with
# the hash substituted. `--replace-fail` means this breaks loudly the moment
# nixpkgs touches that hash itself -- which is the signal to delete this file.
#
# Verified 2026-09-16: the served file is a real 4.09 GB zip, not an error page.
final: prev: let
  upstream = prev.path + "/pkgs/by-name/da/davinci-resolve/package.nix";

  staleHash = "sha256-bQ4Yag4xfIF9Fs0UVKaYFhObMsAof5n+Sy4osw35a9g=";
  currentHash = "sha256-+3SB32EHpH9/0hM3h8CrO6f7V4ZAmxUFh3P8m6QDeO0=";

  patched =
    prev.runCommandLocal "davinci-resolve-package.nix" {} ''
      substitute ${upstream} $out \
        --replace-fail '${staleHash}' '${currentHash}'
    '';
in {
  davinci-resolve = prev.callPackage patched {};
}
