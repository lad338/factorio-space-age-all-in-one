-- Simulacruis's terrain is stitched from five planets' own biomes, so
-- Nauvis's own share of any given zone can be small — and real Nauvis
-- crude-oil isn't guaranteed near spawn even in vanilla
-- (has_starting_area_placement = 0 on crude-oil's own
-- formula, unlike iron-ore/copper-ore/coal/stone, which all set that
-- to 1). Between those two facts, a player can end up with no
-- reachable oil patch anywhere near their starting position on
-- Simulacruis specifically — potentially requiring a long, dangerous
-- trek through another planet's own enemies just to unlock basic
-- plastic/sulfur processing, worse than vanilla's own already-optional
-- oil search ever risks.
--
-- Mitigated with a small, separate, deliberately weak guaranteed
-- starter patch near spawn — not a replacement for real oil
-- exploration (the map's normal crude-oil supply, on both Nauvis- and
-- Aquilo-owned territory, is untouched), just enough to bootstrap
-- early game if none of that normal supply happens to be close by.
-- Toggleable via a startup mod setting, off by default (matching
-- vanilla's own "you might need to go looking for oil" experience) —
-- enable it for the safety net instead.
if not settings.startup["simulacruis-starter-oil-patch"].value then
  return
end

local starter = table.deepcopy(data.raw.resource["crude-oil"])
starter.name = "simulacruis-starter-oil"
-- Fully functional, just not a separate browsable Factoriopedia page
-- (see data-updates.lua's header note) — and visually/functionally
-- identical to real crude oil, so reuse its own display name rather
-- than inventing a distinct one for what the player should just see
-- as "an oil patch".
starter.hidden_in_factoriopedia = true
starter.localised_name = { "entity-name.crude-oil" }

-- Same starting_spot_at_angle mechanism vanilla Gleba's own starting-
-- plant guarantee uses (gleba_starting_fertile) — a smooth proximity
-- field peaking near one specific
-- (angle, distance) point, wobbled for an organic, non-perfectly-
-- circular shape. gleba_starting_angle/_direction and gleba_wobble_x
-- are generic per-seed values (derived from map_seed), not actually
-- Gleba-specific despite the name, so reusing them here doesn't create
-- any real dependency on Gleba's own placement.
--
-- Deliberately NOT gated to any specific zone or planet's own biome
-- ownership: distance = 100 keeps it close enough to reach early
-- regardless of exactly how the zone radii are configured (even Zone
-- 1 disabled entirely via the zone-skip settings), and the point of a
-- guaranteed fallback is to work regardless of whatever biome mix
-- happens to end up nearby.
starter.autoplace = {
  order = "c",
  probability_expression = "starting_spot_at_angle{\z
    angle = gleba_starting_angle + 150 * gleba_starting_direction,\z
    distance = 100,\z
    radius = 2,\z
    x_distortion = gleba_wobble_x * 2,\z
    y_distortion = gleba_wobble_x * 2}",
  -- Flat and low, not real crude-oil's own distance-scaled formula
  -- (which would give this a completely normal yield just by virtue of
  -- being close to spawn — real crude-oil's own richness is highest
  -- close in, not lowest). Independent of the "Crude Oil" map-gen
  -- slider entirely, by design — this is a fixed safety net, not a
  -- tunable resource; a player who wants more/less oil overall should
  -- use that slider, which this patch doesn't participate in either
  -- direction.
  richness_expression = "10000"
}

data:extend({ starter })

local planet_names = { "nauvis", "vulcanus", "fulgora", "gleba", "aquilo", "simulacruis" }
-- New prototype, so AutoplaceSpecification.default_enabled = true
-- means it would otherwise place on every OTHER planet's own map too
-- (real Nauvis/Vulcanus/Fulgora/Gleba/Aquilo) — explicitly disabled
-- everywhere except Simulacruis, same {size = 0} technique used
-- throughout this mod for the reverse case (disabling an ORIGINAL
-- prototype on Simulacruis specifically).
--
-- Simulacruis itself still needs its OWN explicit {} entry below,
-- despite being left enabled — without it, this genuinely new (not
-- cloned-and-renamed-from-an-
-- already-registered-original) prototype placed nowhere at all despite
-- a provably-working probability formula, matching the exact pattern
-- every other resource clone in this mod already follows (nauvis-
-- dressing.lua/planet-resources.lua both register an empty {} entry on
-- Simulacruis, not just {size = 0} disables elsewhere) rather than
-- relying on default_enabled alone.
for _, planet_name in ipairs(planet_names) do
  local planet = data.raw.planet[planet_name]
  if planet then
    local setting = planet_name == "simulacruis" and {} or { size = 0 }
    planet.map_gen_settings.autoplace_settings.entity.settings["simulacruis-starter-oil"] = setting
  end
end
