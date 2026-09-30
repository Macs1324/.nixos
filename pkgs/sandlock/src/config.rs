//! `~/.config/sandlock/config.toml` (or `--config <path>`). Every key is
//! optional; a missing file means all defaults.

use std::path::{Path, PathBuf};

use anyhow::Context;
use serde::Deserialize;

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub(crate) struct Config {
    pub(crate) storm: Storm,
}

/// How the storm moves. 0 turns an ingredient off; 1 is roughly the energy of
/// the first prototype. Values above 1 are allowed.
#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub(crate) struct Storm {
    /// Overall energy: how hard the slow, large-scale wind blows.
    pub(crate) intensity: f32,
    /// Sudden bursts (impulses of push and spin) on top of the wind.
    pub(crate) gusts: f32,
    /// Small curls: vorticity confinement and fine turbulence.
    pub(crate) swirl: f32,
}

impl Default for Storm {
    /// Smooth and flowy: mostly wind, a rare gust, gentle curls.
    fn default() -> Self {
        Self {
            intensity: 0.5,
            gusts: 0.1,
            swirl: 0.35,
        }
    }
}

pub(crate) fn default_path() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
    Some(base.join("sandlock/config.toml"))
}

/// Loads `path`; a missing file is not an error (all defaults), but a broken
/// one is, so typos don't silently fall back.
pub(crate) fn load(path: &Path) -> anyhow::Result<Config> {
    let text = match std::fs::read_to_string(path) {
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Config::default()),
        Err(e) => return Err(e).with_context(|| format!("reading {}", path.display())),
    };
    let config: Config =
        toml::from_str(&text).with_context(|| format!("parsing {}", path.display()))?;
    for (name, value) in [
        ("intensity", config.storm.intensity),
        ("gusts", config.storm.gusts),
        ("swirl", config.storm.swirl),
    ] {
        anyhow::ensure!(
            value.is_finite() && value >= 0.0,
            "storm.{name} must be a number >= 0"
        );
    }
    Ok(config)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn partial_file_keeps_other_defaults() {
        let c: Config = toml::from_str("[storm]\ngusts = 0.0\n").unwrap();
        assert_eq!(c.storm.gusts, 0.0);
        assert_eq!(c.storm.intensity, Storm::default().intensity);
    }

    #[test]
    fn typos_are_errors() {
        assert!(toml::from_str::<Config>("[storm]\nintensty = 1.0\n").is_err());
    }
}
