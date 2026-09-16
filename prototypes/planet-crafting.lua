-- Simulacruis is meant to combine every planet's own buildings and
-- crafting into one place, so none of the normal per-planet surface
-- restrictions should apply here — except the handful of genuinely
-- spaceship-only items (thrusters, thruster fuel/oxidizer), which stay
-- restricted everywhere including Simulacruis, since building those
-- outside of space wouldn't make sense regardless of planet.
--
-- The actual BUILDING entities (foundry, biochamber, electromagnetic-
-- plant, cryogenic-plant, big-mining-drill, recycler, etc.) all have
-- surface_conditions = nil — they can already
-- be built and operated anywhere. The real restriction lives entirely
-- on the RECIPES that craft these building items (and a handful of
-- other planet-locked intermediates/science packs): each requires an
-- exact surface property value matching one specific vanilla planet
-- (e.g. foundry requires pressure = 4000, Vulcanus's own; biochamber
-- requires pressure = 2000, Gleba's own; electromagnetic-plant requires
-- magnetic-field >= 99, Fulgora's own).
--
-- Simulacruis inherited only Nauvis's own surface_properties (day-night-
-- cycle, planet-str) from the clone — everything else falls back to the
-- engine's plain defaults (gravity=10, pressure=1000, magnetic-field=90,
-- solar-power=100, is-freezing=0), i.e. Nauvis-like across the board.
-- Since a single surface can only hold ONE value per property, there is
-- no way to make Simulacruis simultaneously satisfy pressure=4000 AND
-- pressure=2000 AND pressure=300 for different recipes at once.
--
-- Originally fixed via clone+gate (the same pattern used everywhere
-- else in this mod: clone the recipe, relax the clone, leave the
-- original untouched) — but that meant every one of these recipes
-- showed up TWICE in the handcraft/recipe-picker UI (the vanilla
-- restricted original plus our always-available clone), which reads as
-- clutter/confusing rather than helpful. Switched to directly removing
-- `surface_conditions` from the ORIGINAL recipe instead — one recipe,
-- not two.
--
-- Trade-off, explicitly accepted: this lifts the restriction globally,
-- not just on Simulacruis — including on the real Vulcanus/Fulgora/
-- Gleba/Aquilo/Nauvis planets when visited (e.g. a foundry becomes
-- craftable while physically standing on real Gleba too). Judged better
-- than the duplicate-recipe UI clutter.
--
-- thruster-fuel/thruster-oxidizer/advanced-thruster-fuel/advanced-
-- thruster-oxidizer are deliberately excluded, even though they also
-- carry a surface_conditions restriction (gravity = 0, i.e. space
-- only) — these are the spaceship-only exception this file's own
-- header note describes, so they stay restricted to space.
--
-- space-science-pack and promethium-science-pack ARE included (also
-- gravity = 0 normally): both should be craftable on the planet
-- itself so research isn't gated on always having a space platform in
-- flight.
--
-- Considered and declined a partial native-restriction fix: two small
-- subsets of this list COULD be restored to genuine, zero-leak,
-- zero-side-effect Simulacruis+origin-planet-only restriction just by
-- setting Simulacruis's own planet.surface_properties —
-- magnetic-field = 99 exactly matches Fulgora and is used nowhere else
-- in the entire game, so it would cleanly fix
-- recycler/electromagnetic-science-pack/
-- lightning-rod/lightning-collector/electromagnetic-plant; separately,
-- fish-breeding/wood-processing already need exactly pressure = 1000,
-- which Simulacruis already has as its own default (same as Nauvis),
-- so those two already work correctly even without being on this list
-- at all. The other ~22 recipes have no such fix available — Vulcanus/
-- Gleba/Aquilo need mutually exclusive exact pressure values, and no
-- other surface property is free to repurpose as a marker without a
-- real gameplay side effect elsewhere (gravity affects movement/
-- platform thrust, solar-power scales panel output, is-freezing drives
-- freezing mechanics). Rather than have most of this list globally
-- unrestricted while a handful are quietly restored to native
-- planet-matching behavior — a real behavioral difference between
-- entries that isn't obvious just from reading this list — every entry
-- here is treated the same way.
local restricted_recipes = {
  "recycler", "copper-bacteria", "copper-bacteria-cultivation", "iron-bacteria", "iron-bacteria-cultivation",
  "artificial-yumako-soil", "overgrowth-yumako-soil", "artificial-jellynut-soil", "overgrowth-jellynut-soil",
  "pentapod-egg", "metallurgic-science-pack", "agricultural-science-pack",
  "electromagnetic-science-pack", "cryogenic-science-pack", "acid-neutralisation", "foundry",
  "turbo-transport-belt", "turbo-underground-belt", "turbo-splitter", "big-mining-drill", "biochamber",
  "fish-breeding", "lightning-rod", "electromagnetic-plant", "lightning-collector", "cryogenic-plant",
  "quantum-processor", "fusion-reactor", "fusion-generator", "wood-processing",
  "space-science-pack", "promethium-science-pack"
}

for _, name in ipairs(restricted_recipes) do
  data.raw.recipe[name].surface_conditions = nil
end
