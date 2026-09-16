-- Simulacruis's own background music: rather than authoring new
-- tracks, clone EVERY existing ambient-sound entry belonging to
-- Nauvis, Vulcanus, Fulgora, Gleba, or Aquilo, retargeted to
-- "simulacruis" — Factorio's music player rotates through every
-- ambient-sound prototype whose `planet` field names the current
-- surface's own planet (e.g.
-- "vulcanus-1"/"vulcanus-interlude-1"/"vulcanus-3-hero" all carry
-- planet = "vulcanus", and the game cycles through a given planet's
-- own main-track/hero-track/interlude entries while there — this is
-- Factorio 2.0's singular `planet` string field; 2.1 renames it to a
-- `planets` list instead, see docs/factorio-2.0-2.1-compatibility.md).
-- Cloning all of them onto "simulacruis" gives it the full combined
-- playlist from all five real planets, rather than silence (no
-- ambient-sound entry matches "simulacruis" at all otherwise) or a
-- single borrowed planet's music.
--
-- table.deepcopy + rename, not a hand-rebuilt field list — several
-- tracks (e.g. "vulcanus-interlude-1") use a much more elaborate
-- variable_sound/state-machine structure than a plain sound-file
-- reference, and reconstructing that by hand would be extremely
-- error-prone. Same clone+rename pattern used for every other
-- prototype cloned throughout this mod, just without the usual
-- hidden_in_factoriopedia/localised_name follow-up — ambient-sound
-- prototypes are pure internal audio config, never shown in any
-- player-facing menu, so neither concern applies here.
--
-- Purely additive: the originals are untouched and keep playing on
-- the real Nauvis/Vulcanus/Fulgora/Gleba/Aquilo elsewhere in the
-- galaxy — nothing here needs an autoplace-style "disable the
-- original" step, since track selection is a direct planet-name match,
-- not spatial placement that could leak.
--
-- One wrinkle: a planet may have at most one hero-track
-- ("'simulacruis' cannot have multiple hero-tracks"). Nauvis itself
-- has no hero-track prototype at all —
-- only Vulcanus/Gleba/Fulgora/Aquilo do — so instead Simulacruis's
-- hero-track is Nauvis's own "after-the-crash", the track that plays
-- right after Nauvis's own crash-site intro (fitting, since
-- Simulacruis has its own crash-site cutscene too). The 4 real
-- hero-tracks from Vulcanus/Gleba/Fulgora/Aquilo are demoted to
-- main-track — their audio still gets cloned and still plays, just
-- without whatever hero-track-specific trigger condition they had on
-- their original planet.
local SOURCE_PLANETS = {
  nauvis = true,
  vulcanus = true,
  fulgora = true,
  gleba = true,
  aquilo = true,
}
local HERO_TRACK_SOURCE_NAME = "after-the-crash"

-- ambient_sound.planet is a single string (possibly nil for space/menu
-- tracks, which belong to no planet).
local function has_source_planet(ambient_sound)
  return SOURCE_PLANETS[ambient_sound.planet] == true
end

local new_tracks = {}
for name, ambient_sound in pairs(data.raw["ambient-sound"]) do
  if has_source_planet(ambient_sound) then
    local clone = table.deepcopy(ambient_sound)
    clone.name = "simulacruis-" .. name
    clone.planet = "simulacruis"
    if name == HERO_TRACK_SOURCE_NAME then
      clone.track_type = "hero-track"
    elseif clone.track_type == "hero-track" then
      clone.track_type = "main-track"
    end
    table.insert(new_tracks, clone)
  end
end

data:extend(new_tracks)
