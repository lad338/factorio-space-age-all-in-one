-- Clones each non-Nauvis source planet's tile prototypes under
-- simulacruis-specific names, with each clone's autoplace formula
-- wrapped in a zone/ownership gate. This is necessary — not just
-- defensive — because these tiles reference their source planet's own
-- named fields (e.g. vulcanus_elev, gleba_elevation) directly rather
-- than the redirectable elevation/aux/moisture/temperature identifiers,
-- so without gating they would autoplace using that planet's raw,
-- un-zoned geometry across the whole Simulacruis surface. Cloning
-- (rather than mutating data.raw.tile[...] in place) keeps the
-- originals — and therefore real Vulcanus/Fulgora/Gleba/Aquilo terrain
-- elsewhere in the galaxy — untouched.

local function gated_tile_clone(original_name, gate_expression)
  local tile = table.deepcopy(data.raw.tile[original_name])
  tile.name = "simulacruis-" .. original_name
  tile.autoplace = tile.autoplace or {}
  tile.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. tile.autoplace.probability_expression .. ", -inf)"
  -- Fully functional, just not a separate browsable Factoriopedia page
  -- (see data-updates.lua's header note).
  tile.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention
  -- (Factorio derives it from "<category>-name.<internal-name>", which
  -- no longer matches once renamed) — without this, every clone shows
  -- literally "Unknown key" wherever its name is displayed. Re-point at
  -- the ORIGINAL's own locale key rather than writing new locale
  -- entries: same text, respects the player's language, no new files.
  tile.localised_name = { "tile-name." .. original_name }
  return tile
end

local vulcanus_tiles = {
  "volcanic-soil-dark", "volcanic-soil-light", "volcanic-ash-soil",
  "volcanic-ash-flats", "volcanic-ash-light", "volcanic-ash-dark",
  "volcanic-cracks", "volcanic-cracks-warm", "volcanic-folds",
  "volcanic-folds-flat", "volcanic-folds-warm", "volcanic-pumice-stones",
  "volcanic-cracks-hot", "volcanic-jagged-ground", "volcanic-smooth-stone",
  "volcanic-smooth-stone-warm", "volcanic-ash-cracks"
}

local fulgora_tiles = {
  "fulgoran-rock", "fulgoran-dust", "fulgoran-sand", "fulgoran-dunes",
  "fulgoran-walls", "fulgoran-paving", "fulgoran-conduit", "fulgoran-machinery"
}

local gleba_tiles = {
  "natural-yumako-soil", "natural-jellynut-soil", "wetland-yumako", "wetland-jellynut",
  "wetland-blue-slime", "wetland-light-green-slime", "wetland-green-slime",
  "wetland-light-dead-skin", "wetland-dead-skin", "wetland-pink-tentacle",
  "wetland-red-tentacle", "gleba-deep-lake", "lowland-brown-blubber",
  "lowland-olive-blubber", "lowland-olive-blubber-2", "lowland-olive-blubber-3", "lowland-pale-green",
  "lowland-cream-cauliflower", "lowland-cream-cauliflower-2", "lowland-dead-skin",
  "lowland-dead-skin-2", "lowland-cream-red", "lowland-red-vein",
  "lowland-red-vein-2", "lowland-red-vein-3", "lowland-red-vein-4",
  "lowland-red-vein-dead", "lowland-red-infection", "midland-turquoise-bark",
  "midland-turquoise-bark-2", "midland-cracked-lichen", "midland-cracked-lichen-dull",
  "midland-cracked-lichen-dark", "midland-yellow-crust", "midland-yellow-crust-2",
  "midland-yellow-crust-3", "midland-yellow-crust-4", "highland-dark-rock",
  "highland-dark-rock-2", "highland-yellow-rock", "pit-rock"
}

local aquilo_tiles = {
  "snow-flat", "snow-crests", "snow-lumpy", "snow-patchy",
  "ice-rough", "ice-smooth", "brash-ice", "ammoniacal-ocean", "ammoniacal-ocean-2"
}

local new_tiles = {}
local tile_settings = {}
local originals_to_disable = {}

local function add_all(tile_list, gate_expression)
  for _, name in ipairs(tile_list) do
    local clone = gated_tile_clone(name, gate_expression)
    table.insert(new_tiles, clone)
    tile_settings[clone.name] = {}
    table.insert(originals_to_disable, name)
  end
end

add_all(vulcanus_tiles, "simulacruis_vulcanus_weight")
add_all(fulgora_tiles, "simulacruis_fulgora_weight")
add_all(gleba_tiles, "simulacruis_gleba_weight")
add_all(aquilo_tiles, "simulacruis_aquilo_weight")

-- Lava and heavy-oil-sea are dangerous/disruptive enough that they're
-- withheld until Zone 4, well past the early game, rather than
-- appearing as soon as a Vulcanus/Aquilo patch does — so they use a
-- combined gate rather than the plain per-planet ownership weight.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_vulcanus_zone_4_gate",
    expression = "min(simulacruis_vulcanus_weight, simulacruis_zone_4_weight)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_fulgora_zone_4_gate",
    expression = "min(simulacruis_fulgora_weight, simulacruis_zone_4_weight)"
  }
})

local lava = gated_tile_clone("lava", "simulacruis_vulcanus_zone_4_gate")
local lava_hot = gated_tile_clone("lava-hot", "simulacruis_vulcanus_zone_4_gate")
lava.allowed_neighbors = { "simulacruis-lava-hot" }
lava_hot.allowed_neighbors = { "simulacruis-lava" }
table.insert(new_tiles, lava)
table.insert(new_tiles, lava_hot)
tile_settings["simulacruis-lava"] = {}
tile_settings["simulacruis-lava-hot"] = {}
table.insert(originals_to_disable, "lava")
table.insert(originals_to_disable, "lava-hot")

local oil_shallow = gated_tile_clone("oil-ocean-shallow", "simulacruis_fulgora_zone_4_gate")
local oil_deep = gated_tile_clone("oil-ocean-deep", "simulacruis_fulgora_zone_4_gate")
table.insert(new_tiles, oil_shallow)
table.insert(new_tiles, oil_deep)
tile_settings["simulacruis-oil-ocean-shallow"] = {}
tile_settings["simulacruis-oil-ocean-deep"] = {}
table.insert(originals_to_disable, "oil-ocean-shallow")
table.insert(originals_to_disable, "oil-ocean-deep")

data:extend(new_tiles)

-- Merge these clones into Simulacruis's own tile autoplace settings,
-- alongside the Nauvis tiles nauvis-dressing.lua already enabled there.
local planet = data.raw.planet.simulacruis
for name, setting in pairs(tile_settings) do
  planet.map_gen_settings.autoplace_settings.tile.settings[name] = setting
end

-- Disable the originals explicitly. AutoplaceSpecification's
-- default_enabled=true default applies
-- uniformly to tiles too per its own documentation — no tile-specific
-- exception is documented — and this exact mechanism was already
-- observed leaking for trees and resources (thousands of un-gated
-- instances despite never having a settings entry). Applying the same
-- {size = 0} disable here defensively, rather than relying on the
-- earlier (now-suspect) assumption that tiles behave differently.
for _, name in ipairs(originals_to_disable) do
  planet.map_gen_settings.autoplace_settings.tile.settings[name] = { size = 0 }
end
