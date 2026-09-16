-- Vulcanus's and Aquilo's own nuke mechanics (nuking converts nearby
-- ground into a lava crater on Vulcanus, or ice/ammoniacal-ocean on
-- Aquilo) can't be restricted to their own owned patches the way
-- autoplace formulas are. They're gated by data.raw.projectile
-- ["atomic-rocket"]'s target_effects checking the SURFACE's own
-- `pressure` property (data.raw.explosion["nuke-effects-vulcanus"/
-- "nuke-effects-aquilo"].surface_conditions:
-- vulcanus wants pressure == 4000, aquilo wants 100-600) — a single
-- fixed value for the whole surface, not something that can vary by
-- position the way this mod's zone-ownership noise expressions do.
-- Simulacruis is one surface hosting all five planets' biomes, so its
-- `pressure` property can only ever equal ONE value overall — it
-- currently has none set at all (inherited from the Nauvis clone base),
-- so today nuking anywhere on Simulacruis falls through to the vanilla
-- default (nuke-effects-nauvis: a plain "nuclear-ground" scorch),
-- regardless of which planet's biome the nuke actually lands on.
--
-- Fulgora (pressure 800) and Gleba (pressure 2000) don't need an
-- equivalent fix: neither value matches ANY of vanilla's own nuke
-- pressure gates either, so on the real planets themselves nuking
-- already falls through to that same generic nuclear-ground scorch —
-- which already fires unconditionally on Simulacruis today. Only
-- Vulcanus and Aquilo actually have a special effect to restore.
--
-- Fixed with a script-trigger-effect appended to the same
-- target_effects list. This doesn't replace the existing (currently
-- inert on Simulacruis, since its pressure never matches any of them)
-- create-entity effects — it just adds one more callback carrying the
-- actual impact position, so control.lua can check *that specific
-- point's* own simulacruis_vulcanus_weight/simulacruis_aquilo_weight
-- (the same per-position noise expressions tiles.lua/planet-resources.lua
-- already use to gate each planet's own terrain) and manually recreate
-- the matching planet's exact tile effect there. This also automatically
-- covers nuclear reactor meltdowns, which detonate via this same
-- "atomic-rocket" entity (see the on_script_trigger_effect handler in
-- control.lua for both explanations).
table.insert(data.raw.projectile["atomic-rocket"].action.action_delivery.target_effects, {
  type = "script",
  effect_id = "simulacruis-nuke-lava"
})
