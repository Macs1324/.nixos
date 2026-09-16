"""Restore only Nix-owned wallpaper settings when Home Manager is activated."""
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

import tomlkit


def reset_overrides(path, connectors):
    if not path.exists():
        return False
    # Preserve a user's symlink, if the state file itself is linked elsewhere.
    target = path.resolve(strict=True)
    original = target.read_text()
    document = tomlkit.parse(original)
    owned = [
        ("wallpaper", "enabled"),
        ("wallpaper", "automation", "enabled"),
        ("wallpaper", "default", "path"),
        ("wallpaper", "last", "path"),
        *(("wallpaper", "monitors", name, "path") for name in connectors),
    ]
    for keys in owned:
        table = document
        for key in keys[:-1]:
            table = table.get(key, {})
            if not hasattr(table, "get"):
                break
        else:
            if keys[-1] in table:
                del table[keys[-1]]
    updated = tomlkit.dumps(document)
    if updated == original:
        return False

    # Keep the original state as a one-time migration backup. Unrelated UI
    # preferences, comments, and unconfigured connectors stay untouched.
    backup = target.with_name(target.name + ".before-nix-monitors")
    if not backup.exists():
        shutil.copy2(target, backup)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=target.parent, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(updated)
        temporary.chmod(stat.S_IMODE(target.stat().st_mode))
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return True


if __name__ == "__main__":
    connectors = json.loads(Path(sys.argv[1]).read_text())
    state_home = os.environ.get("NOCTALIA_STATE_HOME") or os.environ.get("XDG_STATE_HOME") or sys.argv[2]
    reset_overrides(Path(state_home) / "noctalia/settings.toml", connectors)
