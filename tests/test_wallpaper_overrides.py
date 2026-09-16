"""The wallpaper adapter may reset its own keys, never unrelated shell state."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

import tomlkit

spec = importlib.util.spec_from_file_location(
    "reset_wallpaper_overrides",
    Path(__file__).resolve().parents[1] / "scripts/reset-wallpaper-overrides.py",
)
reset = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reset)


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "settings.toml"
        self.original = '''# Keep this comment and these unrelated choices.
[theme]
mode = "dark"
[wallpaper]
enabled = false
fill_mode = "fit"
[wallpaper.automation]
enabled = true
interval_seconds = 3600
[wallpaper.default]
path = "/old/default.jpg"
[wallpaper.last]
path = "/old/last.jpg"
[wallpaper.monitors.DP-1]
path = "/old/left.jpg"
[wallpaper.monitors.DP-2]
path = "/unmanaged/right.jpg"
'''
        self.path.write_text(self.original)
        self.path.chmod(0o600)

    def test_only_owned_keys_removed_and_backup_kept(self):
        self.assertTrue(reset.reset_overrides(self.path, ["DP-1"]))
        document = tomlkit.parse(self.path.read_text())
        self.assertEqual(document["theme"]["mode"], "dark")
        self.assertEqual(document["wallpaper"]["fill_mode"], "fit")
        self.assertEqual(document["wallpaper"]["automation"]["interval_seconds"], 3600)
        self.assertEqual(document["wallpaper"]["monitors"]["DP-2"]["path"], "/unmanaged/right.jpg")
        self.assertNotIn("path", document["wallpaper"]["monitors"]["DP-1"])
        self.assertNotIn("path", document["wallpaper"]["default"])
        self.assertNotIn("path", document["wallpaper"]["last"])
        self.assertNotIn("enabled", document["wallpaper"])
        self.assertNotIn("enabled", document["wallpaper"]["automation"])
        self.assertIn("# Keep this comment", self.path.read_text())
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(str(self.path) + ".before-nix-monitors").read_text(), self.original)

    def test_idempotent(self):
        reset.reset_overrides(self.path, ["DP-1"])
        original_stat = self.path.stat()
        self.assertFalse(reset.reset_overrides(self.path, ["DP-1"]))
        self.assertEqual(self.path.stat().st_mtime_ns, original_stat.st_mtime_ns)

    def test_symlink_preserved(self):
        link = self.path.with_name("linked.toml")
        link.symlink_to(self.path)
        reset.reset_overrides(link, ["DP-1"])
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.read_text(), self.path.read_text())

    def test_absent_file_is_not_created(self):
        missing = self.path.with_name("missing.toml")
        self.assertFalse(reset.reset_overrides(missing, ["DP-1"]))
        self.assertFalse(missing.exists())

    def test_parse_failure_does_not_change_file(self):
        self.path.write_text("[broken")
        with self.assertRaises(tomlkit.exceptions.ParseError):
            reset.reset_overrides(self.path, ["DP-1"])
        self.assertEqual(self.path.read_text(), "[broken")
        self.assertFalse(Path(str(self.path) + ".before-nix-monitors").exists())


if __name__ == "__main__":
    unittest.main()
