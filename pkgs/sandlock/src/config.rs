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

/// An image (or a live widget) whose opaque pixels pull in the most similar
/// grains, so it emerges from the storm out of the desktop's own pixels.
/// Exactly one of `image`, `clock` and `life` must be set.
#[derive(Debug, Clone, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Attractor {
    /// PNG; pixels with alpha >= 50% become targets.
    #[serde(default)]
    pub(crate) image: Option<PathBuf>,
    /// A live clock instead of an image.
    #[serde(default)]
    pub(crate) clock: Option<Clock>,
    /// Conway's Game of Life instead of an image: it fills its output (or
    /// `width`, keeping the output's shape) with cells that live and die.
    #[serde(default)]
    pub(crate) life: Option<Life>,
    /// Connector name ("DP-1"); default: the largest output.
    #[serde(default)]
    pub(crate) output: Option<String>,
    /// Centre of the image as a fraction of the output.
    #[serde(default = "Attractor::default_position")]
    pub(crate) position: [f32; 2],
    /// Screen pixels per image pixel (a clock is 100 px tall at 1; a Game of
    /// Life fills its output at 1).
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
    /// Colour of a widget's pixels ("#rrggbb"; default white): the colour
    /// its grains are matched against. Images use their own colours.
    #[serde(default)]
    pub(crate) color: Option<Rgb>,
}

/// A Game of Life attractor: square cells on a board that wraps around at
/// the edges, stepping every `period`; when the game dies out, freezes or
/// falls into a short loop, a new one is seeded.
#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub(crate) struct Life {
    /// Cell size in screen px (on a 1440 px tall canvas).
    pub(crate) cell: f32,
    /// Seconds per generation.
    pub(crate) period: f32,
    /// Share of cells alive in a new game.
    pub(crate) fill: f32,
}

impl Default for Life {
    fn default() -> Self {
        Self { cell: 40.0, period: 1.5, fill: 0.3 }
    }
}

/// An sRGB colour, written "#rrggbb" (the "#" is optional).
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct Rgb(pub(crate) [u8; 3]);

impl<'de> Deserialize<'de> for Rgb {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let s = String::deserialize(d)?;
        let hex = s.strip_prefix('#').unwrap_or(&s);
        let channel = |i: usize| hex.get(i..i + 2).and_then(|c| u8::from_str_radix(c, 16).ok());
        match (hex.len(), channel(0), channel(2), channel(4)) {
            (6, Some(r), Some(g), Some(b)) => Ok(Rgb([r, g, b])),
            _ => Err(serde::de::Error::custom(format!("{s:?} is not a \"#rrggbb\" colour"))),
        }
    }
}

/// A clock attractor: the local time in seven-segment digits. Only the digits
/// that change release and recruit grains.
#[derive(Debug, Clone, Copy, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub(crate) struct Clock {
    /// Show seconds (they change faster than `emerge`, so they never settle).
    pub(crate) seconds: bool,
    /// 12-hour time instead of 24-hour.
    pub(crate) twelve_hour: bool,
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

    /// A widget's settings, as the defaults for one in a config file.
    pub(crate) fn widget() -> Self {
        Self {
            image: None,
            clock: None,
            life: None,
            output: None,
            position: Self::default_position(),
            scale: 1.0,
            width: None,
            firmness: Self::half(),
            emerge: Self::default_emerge(),
            reach: Self::default_reach(),
            tone: Tone::default(),
            color: None,
        }
    }

    /// Names the attractor in messages: its image path, or "clock".
    pub(crate) fn describe(&self) -> String {
        match (&self.image, &self.clock, &self.life) {
            (Some(image), _, _) => image.display().to_string(),
            (None, Some(_), _) => "clock".into(),
            (None, None, Some(_)) => "life".into(),
            (None, None, None) => "attractor".into(),
        }
    }

    /// How many of `image`, `clock` and `life` are set (exactly one must be).
    pub(crate) fn sources(&self) -> usize {
        usize::from(self.image.is_some()) + usize::from(self.clock.is_some()) + usize::from(self.life.is_some())
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
    /// Wrong-password eruption: a shockwave of vortices, a much wilder storm
    /// afterwards, and attractor images blown apart. 0 = off.
    pub(crate) eruption: f32,
    /// How strongly moving the mouse stirs the storm. 0 = off.
    pub(crate) mouse: f32,
    /// Seconds per tide: a band sweeping across the screens in which the
    /// desktop reassembles and then erodes again, so the storm never mixes
    /// into one soup. 0 = off.
    pub(crate) tide: f32,
    /// How fast grains spread from crowded areas into thinned-out ones
    /// (1/s), so pulls like tides and attractors leave no empty patches.
    /// 0 = off.
    pub(crate) density: f32,
    /// Share of the desktop at rest at any moment, in quiet zones scattered
    /// across the screens that drift and change shape. 0 = off.
    pub(crate) quiet: f32,
    /// Typical size of a quiet zone (px on a 1440 px tall canvas).
    pub(crate) quiet_size: f32,
    /// Seconds for the quiet zones to change completely.
    pub(crate) quiet_drift: f32,
    /// How calm quiet zones get, 0..1: at 1 their grains come nearly to
    /// rest at home and the desktop shows through clearly; lower, it shows
    /// through blurred and rippling.
    pub(crate) quiet_calm: f32,
}

impl Default for Storm {
    /// Smooth and flowy: mostly wind, a rare gust, gentle curls.
    fn default() -> Self {
        Self {
            intensity: 0.5,
            gusts: 0.1,
            swirl: 0.35,
            eruption: 1.0,
            mouse: 1.0,
            tide: 0.0,
            density: 4.0,
            quiet: 0.3,
            quiet_size: 150.0,
            quiet_drift: 4.0,
            quiet_calm: 0.175,
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
        ("eruption", config.storm.eruption),
        ("mouse", config.storm.mouse),
        ("tide", config.storm.tide),
        ("density", config.storm.density),
        ("quiet", config.storm.quiet),
        ("quiet_size", config.storm.quiet_size),
        ("quiet_drift", config.storm.quiet_drift),
        ("quiet_calm", config.storm.quiet_calm),
    ] {
        anyhow::ensure!(
            value.is_finite() && value >= 0.0,
            "storm.{name} must be a number >= 0"
        );
    }
    for a in &config.attractors {
        anyhow::ensure!(
            a.sources() == 1,
            "{}: an attractor needs exactly one of `image`, `clock` and `life`",
            a.describe()
        );
        if let Some(life) = a.life {
            anyhow::ensure!(
                life.cell >= 4.0 && life.period > 0.0 && (0.0..=1.0).contains(&life.fill),
                "life: cell must be >= 4, period > 0 and fill 0..1"
            );
        }
        anyhow::ensure!(
            a.emerge > 0.0 && a.reach >= 1.0,
            "{}: emerge must be > 0 and reach >= 1",
            a.describe()
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
    fn clock_attractor() {
        let c: Config = toml::from_str("[[attractor]]\nclock = { seconds = true }\n").unwrap();
        let clock = c.attractors[0].clock.unwrap();
        assert!(clock.seconds && !clock.twelve_hour);
        assert!(c.attractors[0].image.is_none());
    }

    #[test]
    fn life_attractor() {
        let c: Config = toml::from_str("[[attractor]]\nlife = { cell = 30 }\n").unwrap();
        let life = c.attractors[0].life.unwrap();
        assert_eq!((life.cell, life.period, life.fill), (30.0, 1.5, 0.3));
        assert_eq!(c.attractors[0].sources(), 1);
    }

    #[test]
    fn widget_colours() {
        let c: Config = toml::from_str("[[attractor]]\nclock = {}\ncolor = \"#83a598\"\n").unwrap();
        assert_eq!(c.attractors[0].color, Some(Rgb([0x83, 0xa5, 0x98])));
        let c: Config = toml::from_str("[[attractor]]\nclock = {}\ncolor = \"FFffFF\"\n").unwrap();
        assert_eq!(c.attractors[0].color, Some(Rgb([255, 255, 255])));
        for bad in ["#83a59", "#83a5980", "#zzzzzz", "blue"] {
            assert!(toml::from_str::<Config>(&format!("[[attractor]]\nclock = {{}}\ncolor = {bad:?}\n")).is_err(), "{bad}");
        }
    }

    #[test]
    fn attractor_needs_one_source() {
        let dir = std::env::temp_dir().join(format!("sandlock-config-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        for text in ["[[attractor]]\n", "[[attractor]]\nimage = \"/x.png\"\nclock = {}\n", "[[attractor]]\nclock = {}\nlife = {}\n"] {
            std::fs::write(&path, text).unwrap();
            assert!(load(&path).is_err(), "{text:?} was accepted");
        }
    }

    #[test]
    fn typos_are_errors() {
        assert!(toml::from_str::<Config>("[storm]\nintensty = 1.0\n").is_err());
    }
}
