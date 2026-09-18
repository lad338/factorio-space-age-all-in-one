-- Zone radii are now driven by TWO layers instead of one flat startup
-- setting: a startup mod setting for each zone's own BASE radius (what
-- "Normal", 1x, Coverage means — the rarely-changed "this is my
-- preferred zone layout" choice, still requiring a restart to edit,
-- same as before), and a per-map Terrain Coverage-only slider (like
-- Water's own Coverage/Scale) that scales away from that base for quick,
-- restart-free retuning per game — same reasoning as the Islands
-- layout's own control (see islands.lua). Coverage = None (0) collapses
-- a zone to the previous zone's own radius regardless of the base,
-- reproducing the old "set to 0 to skip this zone" behavior; setting the
-- BASE itself to 0 (or at/below the previous zone's own base) does the
-- same thing permanently, regardless of what the slider is set to.
--
-- can_be_disabled is left at its default (true) here, unlike Islands'
-- own control — unchecking a zone's radius control to reach None/skip
-- is exactly what "disable this control" already means, so the
-- checkbox's own natural meaning lines up with what it does.
local BASE_ZONE_1_RADIUS = settings.startup["simulacruis-zone-1-radius"].value
local BASE_ZONE_2_RADIUS = settings.startup["simulacruis-zone-2-radius"].value
local BASE_ZONE_3_RADIUS = settings.startup["simulacruis-zone-3-radius"].value
data:extend({
  { type = "autoplace-control", name = "simulacruis_zone_1_radius", category = "terrain", order = "simulacruis-a-zone-radius-1",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_zone_2_radius", category = "terrain", order = "simulacruis-a-zone-radius-2",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_zone_3_radius", category = "terrain", order = "simulacruis-a-zone-radius-3",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
})

-- Same clamping as before (each radius floored to at least the previous
-- zone's own), now expressed with the noise DSL's own max() instead of
-- Lua's math.max, since these are runtime values rather than numbers
-- known at data stage. simulacruis_zone_3plus_weight (planet-resources.
-- lua) and the demolisher tiering (planet-demolishers.lua) both consume
-- these same three names directly, so all consumers automatically agree
-- on the same effective radii with nothing to duplicate.
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_1_radius_value",
    expression = "max(" .. BASE_ZONE_1_RADIUS .. " * control:simulacruis_zone_1_radius:size, 0)" },
  { type = "noise-expression", name = "simulacruis_zone_2_radius_value",
    expression = "max(" .. BASE_ZONE_2_RADIUS .. " * control:simulacruis_zone_2_radius:size, simulacruis_zone_1_radius_value)" },
  { type = "noise-expression", name = "simulacruis_zone_3_radius_value",
    expression = "max(" .. BASE_ZONE_3_RADIUS .. " * control:simulacruis_zone_3_radius:size, simulacruis_zone_2_radius_value)" },
})

-- Ring-width floor: keeps every ring-width-derived quantity below (the
-- transition widths and wobble amplitudes right below, and biome-
-- regions.lua's own patch grid sizes) comfortably non-zero even when a
-- zone collapses to a sliver — a literal 0 grid size crashes with
-- "VoronoiNoise::grid_size must be in [1, 65536] range" there.
local RING_WIDTH_FLOOR = 10
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_2_ring_width",
    expression = "max(simulacruis_zone_2_radius_value - simulacruis_zone_1_radius_value, " .. RING_WIDTH_FLOOR .. ")" },
  { type = "noise-expression", name = "simulacruis_zone_3_ring_width",
    expression = "max(simulacruis_zone_3_radius_value - simulacruis_zone_2_radius_value, " .. RING_WIDTH_FLOOR .. ")" },
})

-- Width of the smooth crossfade between adjacent zones, and the
-- amplitude of each boundary's own radius wobble — both scaled to that
-- boundary's own outer ring width instead of a flat number, so they
-- self-scale with whatever the two Zone controls on either side are set
-- to. Zone 3's own ring width is reused for the Zone 3->4 boundary,
-- same as biome-regions.lua's own ring_width reuse for Zone 4's
-- unbounded growth.
--
-- Scaling each boundary by the ring width AFTER it (rather than the
-- ring before it) means a skipped zone's OWN degenerate ring width
-- (already floored above) automatically shrinks the crossfade that
-- immediately precedes it, but NOT the one right after it — e.g.
-- skipping Zone 2 alone correctly shrinks transition_1 (scaled by
-- zone_2_ring_width, now tiny), but transition_2 is scaled by
-- zone_3_ring_width, unrelated to Zone 2's own skip — left alone, that
-- mismatch would make Zone 2 reappear as a "ghost" ring roughly Zone
-- 3's own transition width wide, instead of fully vanishing. Fixed by
-- explicitly forcing a skipped zone's OWN following boundary tiny too
-- (the simulacruis_zone_N_skipped checks below), on top of the
-- automatic floor a skipped zone's own preceding boundary already gets
-- for free. Zone 3 needs no such explicit case: transition_3 already
-- reuses zone_3_ring_width directly, so it self-floors the same way
-- transition_1 does when Zone 1 (rather than Zone 2) is skipped.
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_1_skipped", expression = "simulacruis_zone_1_radius_value <= 0" },
  { type = "noise-expression", name = "simulacruis_zone_2_skipped", expression = "simulacruis_zone_2_radius_value <= simulacruis_zone_1_radius_value" },
})
local TRANSITION_DENSITY = 0.1
local WOBBLE_AMPLITUDE_FRACTION = 0.07
data:extend({
  { type = "noise-expression", name = "simulacruis_transition_1",
    expression = "if(simulacruis_zone_1_skipped > 0.5, " .. (RING_WIDTH_FLOOR * TRANSITION_DENSITY) ..
                 ", simulacruis_zone_2_ring_width * " .. TRANSITION_DENSITY .. ")" },
  { type = "noise-expression", name = "simulacruis_transition_2",
    expression = "if(simulacruis_zone_2_skipped > 0.5, " .. (RING_WIDTH_FLOOR * TRANSITION_DENSITY) ..
                 ", simulacruis_zone_3_ring_width * " .. TRANSITION_DENSITY .. ")" },
  { type = "noise-expression", name = "simulacruis_transition_3",
    expression = "simulacruis_zone_3_ring_width * " .. TRANSITION_DENSITY },
  { type = "noise-expression", name = "simulacruis_wobble_amplitude_1",
    expression = "if(simulacruis_zone_1_skipped > 0.5, " .. (RING_WIDTH_FLOOR * WOBBLE_AMPLITUDE_FRACTION) ..
                 ", simulacruis_zone_2_ring_width * " .. WOBBLE_AMPLITUDE_FRACTION .. ")" },
  { type = "noise-expression", name = "simulacruis_wobble_amplitude_2",
    expression = "if(simulacruis_zone_2_skipped > 0.5, " .. (RING_WIDTH_FLOOR * WOBBLE_AMPLITUDE_FRACTION) ..
                 ", simulacruis_zone_3_ring_width * " .. WOBBLE_AMPLITUDE_FRACTION .. ")" },
  { type = "noise-expression", name = "simulacruis_wobble_amplitude_3",
    expression = "simulacruis_zone_3_ring_width * " .. WOBBLE_AMPLITUDE_FRACTION },
})

-- Each zone-radius boundary gets its OWN independent wobble field
-- instead of all three reusing the same one at different distance
-- offsets — otherwise a bulge outward at some angle for Zone 1->2 would
-- bulge outward at roughly the same angle for Zone 2->3 and 3->4 too,
-- reading as "obviously concentric circles" from a zoomed-out view.
--
-- Amplitude is deliberately kept to a modest fraction of the boundary's
-- own ring width (not a flat number) specifically so three fully
-- independent wobbles can't plausibly invert the zone_step ordering the
-- weight computation below depends on. Worst-case spread between two
-- independent wobbles is about 2x their amplitude; keeping amplitude to
-- ~7% of a ring width leaves that spread an order of magnitude smaller
-- than the ring itself at any reasonable (non-degenerate) radius
-- configuration.
local function radius_wobble(seed1, amplitude_expr)
  return "distance + multioctave_noise{x = x,\z
                                       y = y,\z
                                       seed0 = map_seed,\z
                                       seed1 = '" .. seed1 .. "',\z
                                       octaves = 3,\z
                                       persistence = 0.5,\z
                                       input_scale = 1/250,\z
                                       output_scale = (" .. amplitude_expr .. ")}"
end

data:extend({
  -- The configured radii are a loose reference, not an exact circle:
  -- this adds a smooth, large-wavelength offset to `distance` before
  -- any zone boundary is computed from it, so the boundary wanders in
  -- and out around the nominal radius instead of forming a perfect
  -- ring (which read as an unnaturally sharp cutoff, e.g. Nauvis water
  -- ending in a razor-straight arc into Fulgora land).
  --
  -- Retained under its original name/seed/amplitude — biome-regions.lua's
  -- own near/far distance-band selection already depends on this exact
  -- field and is unaffected by the independent per-boundary wobbles
  -- below (those are only used for the zone_step crossfade).
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance",
    expression = radius_wobble("simulacruis_radius_wobble", "50")
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_1",
    expression = radius_wobble("simulacruis_radius_wobble_zone_1", "simulacruis_wobble_amplitude_1")
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_2",
    expression = radius_wobble("simulacruis_radius_wobble_zone_2", "simulacruis_wobble_amplitude_2")
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_3",
    expression = radius_wobble("simulacruis_radius_wobble_zone_3", "simulacruis_wobble_amplitude_3")
  },

  -- Step functions: each goes smoothly from 0 to 1 as that boundary's
  -- OWN (independently wobbled) distance crosses its threshold. Zone
  -- weights are the successive differences of these steps, which
  -- telescopes to an exact partition of unity (the 4 zone weights
  -- always sum to 1 at any point) PROVIDED zone_step_1 >= zone_step_2
  -- >= zone_step_3 everywhere — guaranteed by construction when all
  -- three shared one monotonic distance value (the original design),
  -- and still true in practice now that each has its own independent
  -- wobble, because each one's amplitude is kept small relative to the
  -- gap between consecutive radii (see radius_wobble's own comment).
  {
    type = "noise-expression",
    name = "simulacruis_zone_step_1",
    expression = "clamp((simulacruis_wobbled_distance_zone_1 - (simulacruis_zone_1_radius_value - simulacruis_transition_1 / 2)) / simulacruis_transition_1, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_step_2",
    expression = "clamp((simulacruis_wobbled_distance_zone_2 - (simulacruis_zone_2_radius_value - simulacruis_transition_2 / 2)) / simulacruis_transition_2, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_step_3",
    expression = "clamp((simulacruis_wobbled_distance_zone_3 - (simulacruis_zone_3_radius_value - simulacruis_transition_3 / 2)) / simulacruis_transition_3, 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_1_weight",
    expression = "1 - simulacruis_zone_step_1"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_2_weight",
    expression = "simulacruis_zone_step_1 - simulacruis_zone_step_2"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_3_weight",
    expression = "simulacruis_zone_step_2 - simulacruis_zone_step_3"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_4_weight",
    expression = "simulacruis_zone_step_3"
  }
})
