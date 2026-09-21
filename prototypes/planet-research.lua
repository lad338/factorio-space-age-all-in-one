-- With every planet's machines and crafting available from the start
-- on Simulacruis, the vanilla tech tree's own planet-discovery gates
-- (requiring you to have actually landed on Vulcanus/Fulgora/Gleba/
-- Aquilo before researching their technologies) no longer make sense —
-- they'd block research for content you already have physical access
-- to. Every one of the 81 technologies gated (directly or
-- transitively) behind a planet-discovery-* prerequisite ultimately
-- traces back to just six root technologies
-- whose ONLY prerequisite IS a planet-discovery-* tech (all six have
-- unit = nil — free, instant-complete gates, not real research
-- investments). Freeing these six is enough to free the entire
-- downstream tree.
--
-- Each replacement prerequisite below was chosen by tracing that root's
-- own granted recipes down to their ingredients, then finding whichever
-- tech actually unlocks producing that ingredient — e.g. tungsten-
-- carbide grants "carbon" and "tungsten-carbide", both of which need
-- sulfuric acid, which is unlocked by sulfur-processing.
--
-- Skipped entirely when Any Planet Start is spawning the player on a
-- real planet instead of Simulacruis (see control.lua's
-- on_player_created): they'll reach Simulacruis later the normal way,
-- researching each planet's own discovery tech as they actually visit
-- it, so none of this restructuring is needed for that playthrough —
-- and some of it directly conflicts with APS's own per-planet tech-tree
-- changes (e.g. both this file and APS's Vulcanus/Fulgora compatibility
-- patches redirect calcite-processing/recycling's prerequisites, in
-- opposite directions, producing a cycle). APS's own tech tree wins
-- outright rather than being reconciled piecemeal.
local aps_planet = settings.startup["aps-planet"]
if aps_planet and aps_planet.value ~= "none" then return end

local tech = data.raw.technology

-- Defensive against another mod also adding the same prerequisite in
-- this same data-updates stage (e.g. Any Planet Start's own Vulcanus
-- compatibility patch also adds "electric-engine" to big-mining-drill) —
-- a duplicate entry fails Factorio's own prototype validation
-- ("prerequisite is registered more than once").
local function add_prerequisite_if_missing(technology, name)
  for _, existing in ipairs(technology.prerequisites) do
    if existing == name then return end
  end
  table.insert(technology.prerequisites, name)
end

tech["tungsten-carbide"].prerequisites = { "sulfur-processing" }
tech["calcite-processing"].prerequisites = { "sulfur-processing" }

-- recycling grants recycler (needs concrete + processing-unit to
-- build) and scrap-recycling. scrap-recycling can itself yield
-- low-density-structure and battery as results, so both of those
-- techs are included too, so recycling scrap for them isn't tech-wise
-- a complete surprise the first time it happens.
--
-- "Scrap from the start" setting: skips all of that, leaving recycling
-- with NO prerequisites at all — the only remaining gate is then the
-- same one vanilla's own trigger uses (see control.lua's
-- SIMULACRUIS_TRIGGER_TECH_PROXY / complete_trigger_technology): simply
-- picking up some scrap. control.lua's own prerequisite-check loop is
-- a no-op against an empty list, so this is enough on its own — no
-- separate runtime change needed.
if settings.startup["simulacruis-scrap-from-start"].value then
  tech["recycling"].prerequisites = {}
else
  tech["recycling"].prerequisites = { "concrete", "processing-unit", "low-density-structure", "battery" }
end

-- agriculture grants agricultural-tower (needs landfill, an item, and
-- steel-plate) and nutrients-from-spoilage (spoilage has no unlock
-- tech — it's a generic byproduct of anything with a spoil result, not
-- something a recipe produces).
tech["agriculture"].prerequisites = { "landfill", "steel-processing" }

-- heating-tower grants heating-tower/heat-pipe/heat-exchanger/
-- steam-turbine — needs boiler+pipe (steam-power), concrete, and
-- steel-plate (steel-processing). Not particularly Gleba-specific in
-- what it actually requires, despite vanilla filing it under Gleba's
-- discovery tech.
tech["heating-tower"].prerequisites = { "steam-power", "concrete", "steel-processing" }

-- lithium-processing grants lithium (needs holmium-plate + lithium-
-- brine + ammonia) and lithium-plate. holmium-plate is already behind
-- holmium-processing, which itself now correctly resolves back to
-- recycling once that's fixed above — no separate prerequisite needed
-- here for it beyond listing holmium-processing directly. Ammonia is
-- handled below (moved to oil-processing, not listed here), since
-- oil-processing is earlier in the tree and holmium-processing's own
-- (now much deeper) prerequisite chain guarantees it's satisfied by
-- the time lithium-processing is in reach anyway.
tech["lithium-processing"].prerequisites = { "holmium-processing" }

-- foundry's own recipe consumes refined-concrete and lubricant as
-- ingredients, neither guaranteed researched by its
-- existing prerequisites (calcite-processing, tungsten-carbide) alone
-- — "concrete" unlocks refined-concrete (the same tech that unlocks
-- plain concrete too), and "lubricant" unlocks lubricant.
-- low-density-structure is added alongside them as a further gate.
add_prerequisite_if_missing(tech["foundry"], "concrete")
add_prerequisite_if_missing(tech["foundry"], "low-density-structure")
add_prerequisite_if_missing(tech["foundry"], "lubricant")

-- big-mining-drill's own recipe consumes 10 electric-engine-unit,
-- unlocked by "electric-engine" — not
-- guaranteed researched by its existing prerequisites (foundry,
-- electric-mining-drill) alone.
add_prerequisite_if_missing(tech["big-mining-drill"], "electric-engine")

-- promethium-science-pack's own ground-based alternative recipe
-- (planet-promethium.lua's "simulacruis-promethium-science-pack",
-- substituting a spidertron for the vanilla recipe's promethium-
-- asteroid-chunk) consumes a spidertron as an ingredient — not
-- guaranteed researched by this tech's existing prerequisites
-- (biter-egg-handling, fusion-reactor) alone, which share no ancestor
-- with the "spidertron" technology's own prerequisite chain at all.
-- The vanilla recipe itself doesn't need this (promethium-asteroid-
-- chunk is collected, not crafted), but the tech gates both recipes
-- together, so this applies to both paths regardless.
add_prerequisite_if_missing(tech["promethium-science-pack"], "spidertron")

-- lightning-rod (the recipe, granted directly by planet-discovery-
-- fulgora rather than a separate technology) is deliberately left
-- alone: Fulgora's lightning strikes are a whole-surface, non-
-- relocatable mechanic (map_gen_settings has no per-position lightning
-- control the way it does for tiles/entities), so it was never
-- replicated on Simulacruis at all — same category of limitation as
-- cliffs always rendering in Nauvis's own style. Since lightning never
-- strikes here regardless, gating the rod behind actually discovering
-- Fulgora still makes sense — a lightning rod with no lightning to
-- ever collect would just be a decoration if unlocked early.

-- Ammonia has exactly ONE source in the entire game:
-- ammoniacal-solution-separation. Left behind
-- planet-discovery-aquilo, de-gating lithium-processing above would be
-- hollow — researchable early but still unusable without a way to get
-- ammonia. All four of Aquilo's ammonia-family recipes only actually
-- need a chemical plant to craft (three are "chemistry-or-cryogenics"
-- category, one "crafting-with-fluid"), and chemical-plant is unlocked
-- directly by oil-processing — so that's where they move to, rather
-- than piggybacking on lithium-processing itself.
local ammonia_recipes = {
  "ammoniacal-solution-separation", "solid-fuel-from-ammonia",
  "ammonia-rocket-fuel", "ice-platform"
}

local aquilo_effects = tech["planet-discovery-aquilo"].effects
for i = #aquilo_effects, 1, -1 do
  local effect = aquilo_effects[i]
  if effect.type == "unlock-recipe" then
    for _, name in ipairs(ammonia_recipes) do
      if effect.recipe == name then
        table.remove(aquilo_effects, i)
        break
      end
    end
  end
end

local oil_processing = tech["oil-processing"]
oil_processing.effects = oil_processing.effects or {}
for _, name in ipairs(ammonia_recipes) do
  table.insert(oil_processing.effects, { type = "unlock-recipe", recipe = name })
end
