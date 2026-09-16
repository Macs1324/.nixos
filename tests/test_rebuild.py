"""Check rebuild sequencing with fake commands; never activate the real system."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
HOSTS = ["workdesktop", "worklaptop", "homedesktop"]


class RebuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.log = self.directory / "commands"
        # The script resolves the repository from its own location, so give it a
        # throwaway checkout with every host's hardware file present.
        self.repo = self.directory / "repo"
        shutil.copytree(REPO / "scripts", self.repo / "scripts")
        shutil.copy(REPO / "Justfile", self.repo / "Justfile")
        self.script = self.repo / "scripts/rebuild.sh"
        for host in HOSTS:
            hardware = self.repo / "hosts" / host / "hardware-configuration.nix"
            hardware.parent.mkdir(parents=True)
            hardware.write_text("{}\n")
        mock = self.directory / "mock"
        mock.write_text(f'#!{shutil.which("bash")}\n' + '''name=${0##*/}
if [[ "$name" == hostname ]]; then
    echo worklaptop
    exit 0
fi
{ printf '%s' "$name"; printf '<%s>' "$@"; printf '\\n'; } >> "$TEST_COMMAND_LOG"
if [[ "$name" == "${TEST_FAIL:-}" ]]; then exit 1; fi
''')
        mock.chmod(0o755)
        for name in ["nix", "sudo", "nixos-rebuild", "home-manager", "hostname"]:
            (self.directory / name).symlink_to(mock)
        self.env = {
            **os.environ,
            "PATH": f"{self.directory}:{os.environ['PATH']}",
            "TEST_COMMAND_LOG": str(self.log),
            "NIXOS_HOST": "",
        }

    def run_script(self, *args, fail=""):
        result = subprocess.run(
            ["bash", str(self.script), *args],
            env={**self.env, "TEST_FAIL": fail},
            cwd=self.directory,
            text=True,
            capture_output=True,
        )
        commands = self.log.read_text().splitlines() if self.log.exists() else []
        return result, commands

    def test_switch_builds_matching_outputs_before_activation(self):
        result, commands = self.run_script("switch", "workdesktop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, [
            "nix<build><--no-link><.#nixosConfigurations.workdesktop.config.system.build.toplevel><.#homeConfigurations.macs@workdesktop.activationPackage>",
            "sudo<nixos-rebuild><switch><--flake><.#workdesktop>",
            "home-manager<switch><-b><hm-backup><--flake><.#macs@workdesktop>",
        ])

    def test_failed_build_never_activates(self):
        result, commands = self.run_script("switch", "homedesktop", fail="nix")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(commands), 1)
        self.assertTrue(commands[0].startswith("nix<build>"))

    def test_failed_system_activation_stops_before_home(self):
        result, commands = self.run_script("switch", "workdesktop", fail="sudo")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(commands), 2)
        self.assertFalse(any(command.startswith("home-manager") for command in commands))

    def test_build_does_not_activate_and_defaults_to_hostname(self):
        result, commands = self.run_script("build")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(commands), 1)
        self.assertIn("nixosConfigurations.worklaptop", commands[0])
        self.assertIn("homeConfigurations.macs@worklaptop", commands[0])

    def test_home_only_does_not_require_system_build(self):
        result, commands = self.run_script("home", "homedesktop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(commands, ["home-manager<switch><-b><hm-backup><--flake><.#macs@homedesktop>"])

    def test_unknown_host_is_rejected_before_running_commands(self):
        result, commands = self.run_script("switch", "nixmacs")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(commands, [])
        self.assertIn("Choose a host", result.stderr)

    def test_environment_selects_host_before_hostname(self):
        self.env["NIXOS_HOST"] = "homedesktop"
        result, commands = self.run_script("build", "")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nixosConfigurations.homedesktop", commands[0])

    def test_explicit_host_wins_over_environment(self):
        self.env["NIXOS_HOST"] = "worklaptop"
        result, commands = self.run_script("build", "workdesktop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nixosConfigurations.workdesktop", commands[0])

    def test_invalid_environment_is_rejected_without_hostname_fallback(self):
        self.env["NIXOS_HOST"] = "typo"
        result, commands = self.run_script("switch")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(commands, [])

    def test_plain_just_switches_using_environment(self):
        self.env["NIXOS_HOST"] = "homedesktop"
        result = subprocess.run(
            ["just", "--justfile", str(self.repo / "Justfile")],
            env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.log.read_text().splitlines()
        self.assertEqual(len(commands), 3)
        self.assertIn("nixosConfigurations.homedesktop", commands[0])
        self.assertEqual(commands[1], "sudo<nixos-rebuild><switch><--flake><.#homedesktop>")
        self.assertEqual(commands[2], "home-manager<switch><-b><hm-backup><--flake><.#macs@homedesktop>")

    def test_missing_hardware_file_stops_before_building(self):
        (self.repo / "hosts/worklaptop/hardware-configuration.nix").unlink()
        result, commands = self.run_script("switch", "worklaptop")
        self.assertEqual(result.returncode, 3)
        self.assertEqual(commands, [])
        self.assertIn("just hardware worklaptop", result.stderr)

    def test_home_only_does_not_need_hardware_file(self):
        (self.repo / "hosts/worklaptop/hardware-configuration.nix").unlink()
        result, commands = self.run_script("home", "worklaptop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(commands), 1)

    def test_unknown_action_is_rejected(self):
        result, commands = self.run_script("invalid", "workdesktop")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(commands, [])


if __name__ == "__main__":
    unittest.main()
