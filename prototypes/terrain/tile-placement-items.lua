-- Fixes two separate vanilla whitelists-by-exact-tile-name that break
-- once a tile is renamed, affecting seven tiles/items total: foundation,
-- landfill, ice-platform, and Gleba's artificial-yumako-soil/
-- artificial-jellynut-soil/overgrowth-yumako-soil/overgrowth-jellynut-soil.
--
-- 1) The ITEMS that place these tiles gate placement via an explicit
--    place_as_tile.tile_condition list of exact vanilla tile names
--    (NOT the generic collision-mask check
--    place_as_tile also carries in its separate `condition` field).
--    Since every hazard/water tile this mod places on Simulacruis is a
--    renamed clone ("simulacruis-<name>", see tiles.lua/
--    nauvis-dressing.lua), none of them match any entry in these
--    vanilla lists — meaning foundation couldn't be built over
--    Simulacruis's lava or Fulgora-owned oil ocean, landfill couldn't
--    cover its Nauvis/Gleba water or Gleba wetlands, and ice-platform
--    couldn't cover its Aquilo ammoniacal-ocean/brash-ice, even though
--    the real planets all support this.
--
-- 2) The TILES themselves separately carry their own `transitions` list
--    — the neighboring tile names that trigger the raised/3D-looking
--    edge graphic where the tile borders a lower hazard (e.g.
--    landfill's transitions[1].to_tiles lists
--    "water", "lava", "ammoniacal-ocean", etc. by exact name). Same
--    root cause: bordering "simulacruis-water" etc. doesn't match any
--    entry, so the edge renders flat instead of raised — reported
--    in-game as landfill placed on Simulacruis missing its 3D-looking
--    bottom edge.
--
-- Both fixed the same way: append the renamed equivalent of each
-- already-cloned tile already present in the vanilla list.
-- water-green/deepwater-green/water-mud/water-shallow/water-wube are
-- also named in these vanilla lists but have no autoplace of their own,
-- so they never appear on Simulacruis and are skipped — nothing to remap.
--
-- Appending to these shared, single global item/tile prototypes is
-- harmless for the real planets elsewhere in the galaxy: the
-- "simulacruis-" names simply never match any tile that exists there.

local function list_contains(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

local function add_simulacruis_tile_conditions(item_name, original_tile_names)
  local place_as_tile = data.raw.item[item_name].place_as_tile
  for _, original_name in ipairs(original_tile_names) do
    local renamed = "simulacruis-" .. original_name
    if not list_contains(place_as_tile.tile_condition, renamed) then
      table.insert(place_as_tile.tile_condition, renamed)
    end
  end
end

add_simulacruis_tile_conditions("foundation", {
  "water", "deepwater", -- Nauvis
  "wetland-yumako", "wetland-jellynut", -- Gleba
  "wetland-light-green-slime", "wetland-green-slime",
  "wetland-light-dead-skin", "wetland-dead-skin",
  "wetland-pink-tentacle", "wetland-red-tentacle",
  "oil-ocean-shallow", "oil-ocean-deep", -- Fulgora
  "lava", "lava-hot" -- Vulcanus
})

add_simulacruis_tile_conditions("landfill", {
  "water", "deepwater", -- Nauvis
  "wetland-yumako", "wetland-jellynut", "wetland-blue-slime", -- Gleba
  "wetland-light-green-slime", "wetland-green-slime",
  "wetland-light-dead-skin", "wetland-dead-skin",
  "wetland-pink-tentacle", "wetland-red-tentacle",
  "gleba-deep-lake"
})

add_simulacruis_tile_conditions("ice-platform", {
  "ammoniacal-ocean", "ammoniacal-ocean-2", "brash-ice" -- Aquilo
})

-- Gleba's own soil-conversion items — same tile_condition mechanism.
-- Without this, players couldn't place
-- artificial/overgrowth yumako or jellynut soil anywhere on Simulacruis
-- at all, breaking the "convert land, then grow yumako/jellynut" loop
-- there entirely — yumako-tree/jellystem's own tile_restriction already
-- lists "artificial-yumako-soil"/"overgrowth-yumako-soil" etc. by their
-- literal (never-renamed) names, since those two are globally shared
-- tiles a player builds directly, not per-planet autoplace clones — so
-- once placement itself works, growth on top of them needs no separate
-- fix.
add_simulacruis_tile_conditions("artificial-yumako-soil", { "wetland-yumako" })
add_simulacruis_tile_conditions("artificial-jellynut-soil", { "wetland-jellynut" })
add_simulacruis_tile_conditions("overgrowth-yumako-soil", {
  "wetland-light-green-slime", "wetland-green-slime", "wetland-yumako",
  "lowland-olive-blubber", "lowland-olive-blubber-2", "lowland-olive-blubber-3",
  "lowland-brown-blubber", "lowland-pale-green"
})
add_simulacruis_tile_conditions("overgrowth-jellynut-soil", {
  "wetland-pink-tentacle", "wetland-red-tentacle", "wetland-jellynut",
  "lowland-red-vein", "lowland-red-vein-2", "lowland-red-vein-3", "lowland-red-vein-4",
  "lowland-red-vein-dead", "lowland-red-infection", "lowland-cream-red"
})

-- Same root cause as item (2) in this file's header, applied to the
-- three tiles themselves (not just the items that place them).
--
-- transitions_between_transitions (the corner-blending graphics where
-- two different transition types meet) only references transition_group
-- INDICES, not tile names, so it's
-- unaffected by renaming and needs no change.
--
-- Checked against each tile's FULL to_tiles list, not just the subset
-- from tile_condition above — the raised-edge graphic can trigger
-- bordering any of these hazards regardless of placement legality (e.g.
-- ice-platform's own to_tiles already includes lava/wetland names
-- alongside water, for the boundary case where it ends up next to one).
local SIMULACRUIS_CLONED_HAZARD_TILES = {}
for _, name in ipairs({
  "water", "deepwater", -- Nauvis
  "lava", "lava-hot", -- Vulcanus
  "oil-ocean-shallow", "oil-ocean-deep", -- Fulgora
  "wetland-yumako", "wetland-jellynut", "wetland-blue-slime",
  "wetland-light-green-slime", "wetland-green-slime",
  "wetland-light-dead-skin", "wetland-dead-skin",
  "wetland-pink-tentacle", "wetland-red-tentacle", "gleba-deep-lake", -- Gleba
  "ammoniacal-ocean", "ammoniacal-ocean-2", "brash-ice" -- Aquilo
}) do
  SIMULACRUIS_CLONED_HAZARD_TILES[name] = true
end

-- Deduplicates against BOTH the additions collected so far and the
-- to_tiles list itself: foundation,
-- landfill and ice-platform's transitions[1].to_tiles are the exact
-- same underlying table (mutating one through this function was
-- visibly showing up in the others, tripling every addition) — vanilla
-- evidently authors it once and reuses the reference across all three
-- tile definitions. Without this guard, calling this function once per
-- tile re-scans the same already-mutated shared list each time and
-- re-appends duplicates.
--
-- Takes the PROTOTYPE directly (not a name to look up in data.raw.tile)
-- so it can be applied equally to vanilla originals and to our own
-- "simulacruis-<name>" clones below.
local function add_simulacruis_transition_partners(tile)
  for _, transition in ipairs(tile.transitions or {}) do
    if transition.to_tiles then
      local additions = {}
      for _, original_name in ipairs(transition.to_tiles) do
        if SIMULACRUIS_CLONED_HAZARD_TILES[original_name] then
          local renamed = "simulacruis-" .. original_name
          if not list_contains(transition.to_tiles, renamed) and not list_contains(additions, renamed) then
            table.insert(additions, renamed)
          end
        end
      end
      -- Inserted after the scan completes, not during — appending to
      -- to_tiles while iterating it with ipairs is unsafe.
      for _, addition in ipairs(additions) do
        table.insert(transition.to_tiles, addition)
      end
    end
  end
end

add_simulacruis_transition_partners(data.raw.tile["foundation"])
add_simulacruis_transition_partners(data.raw.tile["landfill"])
add_simulacruis_transition_partners(data.raw.tile["ice-platform"])
add_simulacruis_transition_partners(data.raw.tile["artificial-yumako-soil"])
add_simulacruis_transition_partners(data.raw.tile["artificial-jellynut-soil"])
add_simulacruis_transition_partners(data.raw.tile["overgrowth-yumako-soil"])
add_simulacruis_transition_partners(data.raw.tile["overgrowth-jellynut-soil"])

for name, tile in pairs(data.raw.tile) do
  if name:sub(1, string.len("simulacruis-")) == "simulacruis-" then
    add_simulacruis_transition_partners(tile)
  end
end
