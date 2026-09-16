-- Reused to recreate the crash-site wreckage/cutscene on Simulacruis
-- ourselves (see the on_nth_tick(1) handler below) instead of letting
-- freeplay build it on Nauvis before our teleport runs.
local crash_site = require("crash-site")
local util = require("util")

-- Simulacruis should always be reachable, and Nauvis should be
-- reachable exactly when the force has researched space-platform-
-- thruster (see the on_research_finished handler below for why that's
-- the gate) — regardless of whether it's already been unlocked from an
-- earlier run. Idempotent and safe to call repeatedly: re-unlocking
-- Simulacruis every time is harmless, and Nauvis is only ever LOCKED
-- here, never force-unlocked, so a force that already has it (either
-- from finishing the research, or from never having been touched by
-- this mod at all) never has it taken away again by this call.
--
-- Called from BOTH on_init and on_configuration_changed, not on_init
-- alone: on_init only runs for a brand-new game. Adding this mod to an
-- already-in-progress save (or updating it) instead fires
-- on_configuration_changed, which on_init-only code never sees at
-- all — leaving Simulacruis permanently locked (nothing else ever
-- unlocks it) and, worse, Nauvis's own lock state stuck at whatever it
-- last was, with no guaranteed path back to correct. Reapplying this
-- on every configuration change keeps both consistent no matter which
-- event actually created/loaded the save.
local function ensure_simulacruis_space_locations(force)
  if not force.technologies["space-platform-thruster"] then return end
  force.unlock_space_location("simulacruis")
  if not force.technologies["space-platform-thruster"].researched then
    force.lock_space_location("nauvis")
  end
end

local function ensure_simulacruis_space_locations_for_all_forces()
  for _, force in pairs(game.forces) do
    ensure_simulacruis_space_locations(force)
  end
end

script.on_init(function()
  storage.simulacruis_pending_spawns = {}
  -- Guards the crash site/cutscene to the very first player only (see
  -- on_nth_tick(1)) — matches vanilla freeplay's own single-player
  -- assumption (crash_site.is_crash_site_cutscene hardcodes
  -- player_index == 1) and avoids stacking multiple wrecked ships on
  -- top of each other if more players join later.
  storage.simulacruis_crash_site_done = false

  -- freeplay's own on_player_created would build the crash site on
  -- whatever surface the player is CURRENTLY on — which, at that point,
  -- is still Nauvis, since our own teleport (on_nth_tick(1), queued via
  -- on_player_created below) hasn't run yet. Left enabled, the wreckage
  -- would end up on the wrong planet. Disabled here and recreated
  -- ourselves on Simulacruis after the teleport instead.
  if remote.interfaces["freeplay"] and remote.interfaces["freeplay"]["set_disable_crashsite"] then
    remote.call("freeplay", "set_disable_crashsite", true)
  end

  ensure_simulacruis_space_locations_for_all_forces()
end)

script.on_configuration_changed(function()
  ensure_simulacruis_space_locations_for_all_forces()
end)

script.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == "space-platform-thruster" then
    event.research.force.unlock_space_location("nauvis")
  end
end)

-- Queue newly-created players rather than teleporting them immediately,
-- so freeplay's own on_player_created handler (starting inventory, etc.)
-- gets a chance to run first regardless of mod/scenario handler order.
script.on_event(defines.events.on_player_created, function(event)
  storage.simulacruis_pending_spawns = storage.simulacruis_pending_spawns or {}
  table.insert(storage.simulacruis_pending_spawns, event.player_index)
end)

-- Maps each of our zone-gated enemy prototypes (see
-- prototypes/terrain/planet-enemies.lua) to the same ownership-weight
-- noise expression that gates its map-gen placement.
local SIMULACRUIS_ENEMY_HOME_WEIGHT = {
  ["simulacruis-biter-spawner"] = "simulacruis_nauvis_weight",
  ["simulacruis-spitter-spawner"] = "simulacruis_nauvis_weight",
  ["simulacruis-small-worm-turret"] = "simulacruis_nauvis_weight",
  ["simulacruis-medium-worm-turret"] = "simulacruis_nauvis_weight",
  ["simulacruis-big-worm-turret"] = "simulacruis_nauvis_weight",
  ["simulacruis-behemoth-worm-turret"] = "simulacruis_nauvis_weight",
  ["simulacruis-gleba-spawner"] = "simulacruis_gleba_weight",
  ["simulacruis-gleba-spawner-small"] = "simulacruis_gleba_weight",
}

-- Base *expansion* (as opposed to initial map-gen spawning, already
-- confined via autoplace gating in planet-enemies.lua) isn't restricted
-- by biome at all in vanilla: Factorio's expansion algorithm scores
-- candidate chunks purely on distance from player buildings/other
-- bases, with no concept of "is this tile actually this species' home
-- biome". Left alone, a Nauvis or Gleba colony could expand into any
-- other biome's territory over time — especially now that the
-- land-bridge fix (biome-regions.lua) guarantees walkable land
-- connections between every neighboring biome.
--
-- Fixed by checking each newly-built expansion entity's own ownership
-- weight (the exact same simulacruis_<planet>_weight noise expression
-- used to gate its map-gen placement) via LuaSurface::
-- calculate_tile_properties, and destroying the entity if it landed
-- outside its home biome (weight <= 0.5, the same threshold the
-- data-stage gating uses). This only affects entities built via
-- expansion (on_biter_base_built) — normal combat losses are untouched.
script.on_event(defines.events.on_biter_base_built, function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  local property = SIMULACRUIS_ENEMY_HOME_WEIGHT[entity.name]
  if not property then return end

  local result = entity.surface.calculate_tile_properties({ property }, { entity.position })
  local values = result[property]
  local value = values and values[1]

  if value == nil or value <= 0.5 then
    entity.destroy()
  end
end)

-- Several vanilla technologies (spanning all four non-Nauvis planets)
-- auto-complete via a `research_trigger`, most commonly "mine-entity"
-- matching one EXACT entity prototype name (e.g. agriculture triggers
-- on mining literally "iron-stromatolite").
-- Since every one of those entities is cloned as "simulacruis-<name>"
-- here (with the original disabled), none of these ever complete on
-- Simulacruis: agriculture, oil-processing, uranium-processing,
-- calcite-processing, tungsten-carbide, recycling, yumako, jellynut,
-- heating-tower, lithium-processing. oil-processing and
-- uranium-processing alone gate most of the mid-game, so this isn't a
-- cosmetic gap. Fixed below by completing each one manually once its
-- renamed clone's own equivalent condition is met.
--
-- Two different completion conditions are needed, split by the source
-- entity's own prototype TYPE: mining a simple-entity/plant clone (e.g.
-- "simulacruis-iron-stromatolite") never updates item/fluid production
-- statistics, even though the mining itself genuinely succeeds and
-- transfers items — only true resource-type extraction (e.g.
-- "simulacruis-calcite") does. Fix A below polls production statistics
-- for the resource-type sources; Fix B listens for the mine event
-- directly for the simple-entity/plant sources, since stats can't see
-- those at all.
--
-- Setting `.researched = true` directly applies the technology's own
-- effects, but doesn't reliably produce the normal "research
-- completed" sound + notification. Every completion here goes through
-- this one helper so the feedback is consistent regardless.
--
-- Every one of these technologies has real prerequisites (e.g.
-- tungsten-carbide requires sulfur-processing, agriculture requires
-- landfill+steel-processing) that vanilla's own engine-native
-- research_trigger respects: mining the trigger entity before its tech
-- is actually eligible doesn't bypass the tech tree. Setting
-- `.researched = true` unconditionally here would let a player skip
-- straight past prerequisites just by mining the right entity early.
-- If a prerequisite isn't met yet, this just no-ops: Fix A's own
-- on_nth_tick(60) poll re-checks its (naturally persistent) production-
-- statistics condition on every pass regardless, but Fix B's
-- mine-entity trigger is a one-shot event — mining too early doesn't
-- count, and the player has to mine another one after finishing the
-- prerequisite.
local function complete_trigger_technology(technology)
  if not technology or technology.researched then return end
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then return end
  end
  technology.researched = true
  for _, player in pairs(technology.force.players) do
    player.play_sound({ path = "utility/research_completed" })
    player.print({ "", "[technology=" .. technology.name .. "] ", technology.localised_name, " researched." })
  end
end

-- Fix A — true resource-type sources (oil-processing/crude-oil,
-- uranium-processing/uranium-ore, calcite-processing/calcite): poll
-- production statistics. Correct for both manual and automated
-- extraction alike (statistics count every source), and rename-agnostic
-- (item names were never renamed, only entities/tiles/recipes were).
local SIMULACRUIS_TRIGGER_TECH_PROXY = {
  ["oil-processing"] = { stats = "fluid", name = "crude-oil" },
  ["uranium-processing"] = { stats = "item", name = "uranium-ore" },
  ["calcite-processing"] = { stats = "item", name = "calcite" },
}

script.on_nth_tick(60, function()
  if not game.surfaces["simulacruis"] then return end
  local force = game.forces.player
  if not force then return end

  for tech_name, proxy in pairs(SIMULACRUIS_TRIGGER_TECH_PROXY) do
    local technology = force.technologies[tech_name]
    if technology and not technology.researched then
      local stats = proxy.stats == "fluid"
        and force.get_fluid_production_statistics("simulacruis")
        or force.get_item_production_statistics("simulacruis")
      if stats.get_input_count(proxy.name) > 0 then
        complete_trigger_technology(technology)
      end
    end
  end
end)

-- Fix B — simple-entity/plant sources (agriculture/iron-stromatolite,
-- heating-tower/copper-stromatolite, yumako/yumako-tree, jellynut/
-- jellystem, lithium-processing/lithium-iceberg-big, tungsten-carbide/
-- big-volcanic-rock, recycling/fulgoran-ruin-vault): since production
-- statistics don't track these at all, listen directly for the player
-- mining our renamed clone entity instead — actually closer to
-- vanilla's own trigger semantics (an exact entity check) than Fix A's
-- item-proxy approach, just aimed at our renamed identity rather than
-- the disabled original. recycling in particular matches vanilla's own
-- `research_trigger = {type="mine-entity", entity="fulgoran-ruin-vault"}`
-- exactly, the same way tungsten-carbide matches vanilla's own
-- big-volcanic-rock trigger below — just aimed at
-- "simulacruis-fulgoran-ruin-vault" (a simple-entity, same category as
-- every other entry here) instead of the disabled original.
--
-- Automated harvesting doesn't apply to any of these eight (none are
-- resource-category entities a mining drill can target), so
-- on_player_mined_entity alone is sufficient — no automated-extraction
-- gap to worry about here, unlike the resource-type cases above.
--
-- huge-volcanic-rock is Vulcanus's other rock type (it also yields
-- tungsten-ore, same as big-volcanic-rock), included alongside it so
-- either one triggers tungsten-carbide.
local SIMULACRUIS_MINE_ENTITY_TRIGGER_TECH = {
  ["simulacruis-iron-stromatolite"] = "agriculture",
  ["simulacruis-copper-stromatolite"] = "heating-tower",
  ["simulacruis-yumako-tree"] = "yumako",
  ["simulacruis-jellystem"] = "jellynut",
  ["simulacruis-lithium-iceberg-big"] = "lithium-processing",
  ["simulacruis-big-volcanic-rock"] = "tungsten-carbide",
  ["simulacruis-huge-volcanic-rock"] = "tungsten-carbide",
  ["simulacruis-fulgoran-ruin-vault"] = "recycling",
}

script.on_event(defines.events.on_player_mined_entity, function(event)
  local tech_name = SIMULACRUIS_MINE_ENTITY_TRIGGER_TECH[event.entity.name]
  if not tech_name then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  -- One-shot: see complete_trigger_technology's own header for why an
  -- unmet prerequisite here isn't remembered for a later retry.
  complete_trigger_technology(player.force.technologies[tech_name])
end)

script.on_nth_tick(1, function()
  local pending = storage.simulacruis_pending_spawns
  if not pending or #pending == 0 then
    return
  end

  local simulacruis = game.planets["simulacruis"]
  if not simulacruis then
    storage.simulacruis_pending_spawns = {}
    return
  end

  local surface = simulacruis.surface
  local is_new_surface = surface == nil
  surface = surface or simulacruis.create_surface()

  if is_new_surface then
    -- Nauvis's own spawn area is already fully generated by the time
    -- on_player_created ever fires — it's part of the initial map
    -- generation the engine runs at game creation, well before any
    -- player exists. Simulacruis's surface, by contrast, is created
    -- lazily right here, on-demand, so none of its surrounding chunks
    -- exist yet at this point.
    --
    -- Without forcing generation up front, everything below runs
    -- against still-generating terrain. The main "crash-site-spaceship"
    -- entity is created unconditionally (crash-site.lua never collision-
    -- checks it), so it still shows up — but every debris/wreck piece
    -- IS collision-checked (can_place_entity, then a
    -- find_non_colliding_position fallback) and silently fails to place
    -- against ungenerated ground, matching the reported "only the ship
    -- appears, the debris doesn't". The cutscene camera pan has nothing
    -- rendered to pan across either, so the player sees the
    -- skip-cutscene prompt over a still-loading view instead of a
    -- smooth pan.
    --
    -- Covers the character's own spawn-search radius (64 tiles, see
    -- find_non_colliding_position below), the ship's offset from that
    -- position (6 tiles), and the cutscene's own 60-tile pan-in
    -- distance (crash-site.lua's create_cutscene) — 5 chunks (160
    -- tiles) from world origin comfortably covers all three regardless
    -- of exactly where find_non_colliding_position ends up placing the
    -- character.
    surface.request_to_generate_chunks({ 0, 0 }, 5)
    surface.force_generate_chunk_requests()
  end

  for _, player_index in ipairs(pending) do
    local player = game.get_player(player_index)
    if player then
      -- x/y-keyed fallback (not array-style {0,0}) so position.x/position.y
      -- below are always safe to read even if find_non_colliding_position
      -- fails — Factorio's MapPosition accepts either style equally.
      local position = surface.find_non_colliding_position("character", { 0, 0 }, 64, 1) or { x = 0, y = 0 }
      player.teleport(position, surface)

      -- Only the very first player gets the crash site + cutscene (see
      -- storage.simulacruis_crash_site_done in on_init), and only when
      -- freeplay's own version was actually disabled above — if some
      -- other scenario is running instead of freeplay, there's no
      -- crash-site concept to restore at all.
      if not storage.simulacruis_crash_site_done
        and remote.interfaces["freeplay"] and remote.interfaces["freeplay"]["get_ship_items"] then
        storage.simulacruis_crash_site_done = true

        local ship_items = remote.call("freeplay", "get_ship_items") or {}
        local debris_items = remote.call("freeplay", "get_debris_items") or {}
        local ship_parts = remote.call("freeplay", "get_ship_parts")

        -- Same relative offsets vanilla freeplay uses for its own
        -- crash site ({-5,-6} ship / {-5,-4} cutscene goal, both
        -- relative to wherever the player actually lands here rather
        -- than a hardcoded {0,0} — vanilla can hardcode because its
        -- spawn is always exactly {0,0}, but ours is wherever
        -- find_non_colliding_position placed the player above).
        local ship_position = { x = position.x - 5, y = position.y - 6 }
        -- Array-style, not {x=..., y=...} — crash-site.lua's own
        -- create_cutscene indexes its goal_position argument as
        -- goal_position[1]/[2] with no dictionary-style fallback
        -- (unlike create_crash_site's position argument just above,
        -- which accepts either style).
        local cutscene_goal = { position.x - 5, position.y - 4 }

        surface.daytime = 0.7
        crash_site.create_crash_site(surface, ship_position, util.copy(ship_items), util.copy(debris_items), ship_parts)
        -- Matches vanilla: these items were already granted as part of
        -- the normal starting inventory, then pulled back out here so
        -- they have to be salvaged from the wreckage instead of
        -- starting in-hand.
        util.remove_safe(player, ship_items)
        util.remove_safe(player, debris_items)
        player.get_main_inventory().sort_and_merge()

        if player.character then
          player.character.destructible = false
        end
        storage.simulacruis_crash_site_cutscene_active = true
        crash_site.create_cutscene(player, cutscene_goal)
      end
    end
  end

  storage.simulacruis_pending_spawns = {}
end)

-- freeplay's own on_cutscene_waypoint_reached/on_cutscene_cancelled
-- handlers check ITS OWN storage.crash_site_cutscene_active — and
-- `storage` is namespaced per mod/scenario in Factorio 2.0, so a cutscene
-- WE start (above) never sets that flag and freeplay's handlers just
-- no-op for it. Replicated here against our own storage flag instead,
-- mirroring crash-site.lua's own exit/cleanup logic exactly.
script.on_event(defines.events.on_cutscene_waypoint_reached, function(event)
  if not storage.simulacruis_crash_site_cutscene_active then return end
  if not crash_site.is_crash_site_cutscene(event) then return end

  local player = game.get_player(event.player_index)
  if player then
    player.exit_cutscene()
  end
end)

script.on_event(defines.events.on_cutscene_cancelled, function(event)
  if not storage.simulacruis_crash_site_cutscene_active then return end
  if event.player_index ~= 1 then return end

  storage.simulacruis_crash_site_cutscene_active = nil
  local player = game.get_player(event.player_index)
  if not player then return end

  if player.gui.screen.skip_cutscene_label then
    player.gui.screen.skip_cutscene_label.destroy()
  end
  if player.character then
    player.character.destructible = true
  end
  player.zoom = 1.5
end)

-- Lets the player skip the crash-site cutscene via the vanilla
-- "crash-site-skip-cutscene" custom input (already defined by base,
-- freeplay just binds a handler to it the same way).
script.on_event("crash-site-skip-cutscene", function(event)
  if not storage.simulacruis_crash_site_cutscene_active then return end
  if event.player_index ~= 1 then return end

  local player = game.get_player(event.player_index)
  if player and player.controller_type == defines.controllers.cutscene then
    player.exit_cutscene()
  end
end)

script.on_event(defines.events.on_player_display_resolution_changed, crash_site.on_player_display_refresh)
script.on_event(defines.events.on_player_display_scale_changed, crash_site.on_player_display_refresh)

-- See prototypes/terrain/nuke-lava.lua for why this needs a script hook
-- instead of the vanilla data-only gate: Simulacruis's single shared
-- `pressure` surface property can't tell which planet's biome a nuke
-- actually landed on, so the per-position check happens here instead,
-- using the same simulacruis_<planet>_weight noise expressions the data
-- stage already uses to gate each planet's own terrain placement.
--
-- Only Vulcanus and Aquilo get an entry here — those are the only two
-- of the four non-Nauvis planets vanilla gives a special nuke
-- tile-conversion effect at all: nuke-effects-vulcanus requires
-- surface pressure == 4000 (Vulcanus's own value) and
-- nuke-effects-aquilo requires 100-600 (Aquilo's own value, 300).
-- Fulgora (pressure 800) and Gleba (pressure 2000) don't
-- match ANY of vanilla's own pressure gates either — meaning on the
-- real planets themselves, nuking Fulgora or Gleba already falls
-- through to the same unconditional "nuclear-ground" scorch effect
-- Nauvis gets (nuke-effects-nauvis has no surface_conditions at all).
-- That fallback already fires unconditionally on Simulacruis today, so
-- Fulgora/Gleba already match their real planet's own behavior with no
-- extra code needed — only Vulcanus and Aquilo were actually missing
-- anything.
local SIMULACRUIS_NUKE_TILE_EFFECTS = {
  { weight = "simulacruis_vulcanus_weight", inner = "lava-hot", outer = "lava" },
  { weight = "simulacruis_aquilo_weight", inner = "ammoniacal-ocean", outer = "brash-ice" },
}

local function simulacruis_set_tile_disk(surface, center, radius, tile_name)
  local tiles = {}
  local cx, cy = math.floor(center.x), math.floor(center.y)
  for dx = -radius, radius do
    for dy = -radius, radius do
      if dx * dx + dy * dy <= radius * radius then
        local x, y = cx + dx, cy + dy
        local tile = surface.get_tile(x, y)
        -- Matches the real effects' own tile_collision_mask exclusion
        -- — skip existing water so oceans don't get paved over.
        -- Simplified vs. vanilla's own split (there, only the outer
        -- radius excludes water, not the inner one) to the same
        -- exclusion on both disks — never overwriting
        -- water is strictly safer, and the difference is only visible
        -- for a pond that happens to sit within the inner blast radius.
        if tile.valid then
          local collision = tile.prototype.collision_mask
          local is_water = collision and collision.layers and collision.layers.water_tile
          if not is_water then
            table.insert(tiles, { name = tile_name, position = { x, y } })
          end
        end
      end
    end
  end
  surface.set_tiles(tiles, true)
end

-- The same "atomic-rocket" projectile (whose action.action_delivery.
-- target_effects we appended this script effect to) is also what a
-- nuclear reactor meltdown creates to detonate itself, so this handler
-- covers reactor meltdowns automatically too, with no separate hook.
script.on_event(defines.events.on_script_trigger_effect, function(event)
  if event.effect_id ~= "simulacruis-nuke-lava" then return end

  local surface = game.surfaces[event.surface_index]
  if not surface or surface.name ~= "simulacruis" then return end

  local position = event.target_position or event.source_position
  if not position then return end

  local weight_names = {}
  for _, cfg in ipairs(SIMULACRUIS_NUKE_TILE_EFFECTS) do
    table.insert(weight_names, cfg.weight)
  end
  local result = surface.calculate_tile_properties(weight_names, { position })

  for _, cfg in ipairs(SIMULACRUIS_NUKE_TILE_EFFECTS) do
    local values = result[cfg.weight]
    local weight = values and values[1]
    if weight and weight > 0.5 then
      -- Same radii/order as the real per-planet nuke effect: the inner
      -- radius-8 disk is filled first, then the larger, overlapping
      -- radius-12 disk second — replicated in the same order for
      -- parity, even though the second call ends up covering the
      -- shared inner area, exactly like the real planet.
      simulacruis_set_tile_disk(surface, position, 8, cfg.inner)
      simulacruis_set_tile_disk(surface, position, 12, cfg.outer)
      return
    end
  end
end)

-- Fulgoran ruins are pre-existing found structures, not player-built —
-- every other ruin fragment (vault/small/medium/big/huge/colossal/
-- stonehenge) is placed by autoplace with force = "neutral", so
-- destroying them never raises a "your building was destroyed" alert.
-- "fulgoran-ruin-attractor" is the one exception: as a
-- lightning-attractor type entity it's placed with force = "player"
-- instead — an inherent vanilla quirk of that entity type, not
-- something this mod's renaming introduced. Harmless on real Fulgora,
-- which has no native enemies at all, so nothing but the player's own
-- actions could ever destroy one there — but on Simulacruis,
-- Vulcanus's demolishers can wander into Fulgora-owned territory and
-- destroy one, incorrectly raising the "entity destroyed" alert for a
-- structure the player never built.
--
-- Cleared via LuaPlayer.remove_alert (alerts are per-player, not
-- per-force — LuaForce has no alert methods at all) rather than
-- reassigning the entity's own force to neutral, since that force may
-- still matter for the lightning-attractor's own protective mechanic
-- and isn't something this mod should second-guess.
script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == "simulacruis-fulgoran-ruin-attractor") then return end
  local force = event.force
  if not force then return end
  for _, player in pairs(force.players) do
    player.remove_alert({ entity = entity, type = defines.alert_type.entity_destroyed })
  end
end)


