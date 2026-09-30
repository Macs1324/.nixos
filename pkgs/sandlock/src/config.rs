//! `~/.config/sandlock/config.toml` (or `--config <path>`). Every key is
//! optional; a missing file means all defaults.

use std::path::{Path, PathBuf};

use anyhow::Context;
use serde::Deserialize;

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub(crate) struct Config {
    pub(crate) storm: Storm,
    /// `[[attractor]]` entries, drawn in order (later ones win on overlap).
    #[serde(rename = "attractor")]
    pub(crate) attractors: Vec<Attractor>,
}

/// An image whose opaque pixels pull in the most similar grains, so it
/// emerges from the storm out of the desktop's own pixels.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Attractor {
    /// PNG; pixels with alpha >= 50% become targets.
    pub(crate) image: PathBuf,
    /// Connector name ("DP-1"); default: the largest output.
    #[serde(default)]
    pub(crate) output: Option<String>,
    /// Centre of the image as a fraction of the output.
    #[serde(default = "Attractor::default_position")]
    pub(crate) position: [f32; 2],
    /// Screen pixels per image pixel.
    #[serde(default = "Attractor::one")]
    pub(crate) scale: f32,
    /// Width in screen pixels (overrides `scale`, keeps the aspect ratio).
    #[serde(default)]
    pub(crate) width: Option<f32>,
    /// 0 = loose (ripples far with the storm) .. 1 = firm.
    #[serde(default = "Attractor::half")]
    pub(crate) firmness: f32,
    /// Seconds until the image has (mostly) formed.
    #[serde(default = "Attractor::default_emerge")]
    pub(crate) emerge: f32,
    /// How far (screen px) a target pixel looks for a matching grain.
    #[serde(default = "Attractor::default_reach")]
    pub(crate) reach: f32,
    /// How target colours are matched against the desktop's grains.
    #[serde(default)]
    pub(crate) tone: Tone,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub(crate) enum Tone {
    /// The image's brightness range is stretched onto the desktop's, so its
    /// shading reads even where its colours don't exist on screen.
    #[default]
    Relative,
    /// Match the image's literal colours.
    Absolute,
}

impl Attractor {
    fn default_position() -> [f32; 2] {
        [0.5, 0.35]
    }
    fn one() -> f32 {
        1.0
    }
    fn half() -> f32 {
        0.5
    }
    fn default_emerge() -> f32 {
        4.0
    }
    fn default_reach() -> f32 {
        150.0
    }
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
    for a in &config.attractors {
        anyhow::ensure!(
            a.emerge > 0.0 && a.reach >= 1.0,
            "{}: emerge must be > 0 and reach >= 1",
            a.image.display()
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
    fn attractor_defaults() {
        let c: Config = toml::from_str("[[attractor]]\nimage = \"/x.png\"\nwidth = 400\n").unwrap();
        assert_eq!(c.attractors.len(), 1);
        assert_eq!(c.attractors[0].position, [0.5, 0.35]);
        assert_eq!(c.attractors[0].width, Some(400.0));
    }

    #[test]
    fn typos_are_errors() {
        assert!(toml::from_str::<Config>("[storm]\nintensty = 1.0\n").is_err());
    }
}
