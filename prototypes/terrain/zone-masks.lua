-- Zone radii come from startup mod settings (fixed at game creation).
-- Same clamping (each radius floored to at least the previous zone's
-- own) as biome-regions.lua uses — see that file's own header comment
-- for the full "setting a radius to 0 skips that zone" rationale; both
-- files must agree on the same effective radii.
local zone_1_radius = math.max(settings.startup["simulacruis-zone-1-radius"].value, 0)
local zone_2_radius = math.max(settings.startup["simulacruis-zone-2-radius"].value, zone_1_radius)
local zone_3_radius = math.max(settings.startup["simulacruis-zone-3-radius"].value, zone_2_radius)

-- Same ring-width derivation (and the same floor value, matching
-- biome-regions.lua's own grid_size-minimum reasoning even though this
-- file's own uses — transition widths, wobble amplitudes — have no
-- such minimum themselves) biome-regions.lua uses for patch sizing —
-- duplicated here (each file independently re-reads the raw radii
-- settings too) rather than shared, since these files have no existing
-- mechanism to share locals across require() boundaries.
local RING_WIDTH_FLOOR = 10
local zone_2_ring_width = math.max(zone_2_radius - zone_1_radius, RING_WIDTH_FLOOR)
local zone_3_ring_width = math.max(zone_3_radius - zone_2_radius, RING_WIDTH_FLOOR)

-- Width of the smooth crossfade between adjacent zones, and the
-- amplitude of each boundary's own radius wobble — both scaled to that
-- boundary's own outer ring width, the same self-scaling approach
-- biome-regions.lua's patch_density uses for patch sizes, instead of a
-- flat 64/50 that was tuned to feel right at Zone 2's scale but became
-- a rounding error next to Zone 4's much larger patches. Zone 3's own
-- ring width is reused for the Zone 3→4 boundary, same as
-- biome-regions.lua's own ring_width reuse for Zone 4's unbounded growth.
--
-- Scaling each boundary by the ring width AFTER it (rather than the
-- ring before it) means a skipped zone's OWN degenerate ring width
-- (already floored to RING_WIDTH_FLOOR above) automatically shrinks
-- the crossfade that immediately precedes it, but NOT the one right
-- after it — e.g. skipping Zone 2 alone (zone_2_radius clamped down to
-- zone_1_radius) correctly shrinks transition_1 (scaled by
-- zone_2_ring_width, now tiny), but transition_2 is scaled by
-- zone_3_ring_width, which is still a normal, non-degenerate value
-- unrelated to Zone 2's own skip — left alone, that mismatch would
-- make Zone 2 reappear as a "ghost" ring roughly Zone 3's own
-- transition width wide, instead of fully vanishing. Fixed by
-- explicitly forcing a skipped zone's OWN following boundary tiny too
-- (zone_N_skipped below), on top of the automatic floor a skipped
-- zone's own preceding boundary already gets for free. Zone 3 needs no
-- such explicit case: transition_3 already reuses zone_3_ring_width
-- directly, so it self-floors the same way transition_1 does when
-- Zone 1 (rather than Zone 2) is what's skipped.
local zone_1_skipped = zone_1_radius <= 0
local zone_2_skipped = zone_2_radius <= zone_1_radius

local transition_density = 0.1
local wobble_amplitude_fraction = 0.07
local transition_1 = zone_1_skipped and (RING_WIDTH_FLOOR * transition_density) or (zone_2_ring_width * transition_density)
local transition_2 = zone_2_skipped and (RING_WIDTH_FLOOR * transition_density) or (zone_3_ring_width * transition_density)
local transition_3 = zone_3_ring_width * transition_density
local wobble_amplitude_1 = zone_1_skipped and (RING_WIDTH_FLOOR * wobble_amplitude_fraction) or (zone_2_ring_width * wobble_amplitude_fraction)
local wobble_amplitude_2 = zone_2_skipped and (RING_WIDTH_FLOOR * wobble_amplitude_fraction) or (zone_3_ring_width * wobble_amplitude_fraction)
local wobble_amplitude_3 = zone_3_ring_width * wobble_amplitude_fraction

-- Each zone-radius boundary gets its OWN independent wobble field
-- instead of all three reusing the same one at different distance
-- offsets. Previously, if the boundary bulged outward at some angle
-- for Zone 1→2, it bulged outward at roughly the same angle for
-- Zone 2→3 and 3→4 too — same underlying noise, just evaluated against
-- different thresholds — which read as "obviously concentric circles"
-- from a zoomed-out view rather than three independently organic
-- boundaries.
--
-- Amplitude is deliberately kept to a modest fraction of the
-- boundary's own ring width (not a flat number) specifically so three
-- fully independent wobbles can't plausibly invert the zone_step
-- ordering the weight computation below depends on — see that comment
-- for why this matters. Worst-case spread between two independent
-- wobbles is about 2x their amplitude; keeping amplitude to ~7% of a
-- ring width leaves that spread an order of magnitude smaller than the
-- ring itself at any reasonable (non-degenerate) radius configuration.
local function radius_wobble(seed1, amplitude)
  return "distance + multioctave_noise{x = x,\z
                                       y = y,\z
                                       seed0 = map_seed,\z
                                       seed1 = '" .. seed1 .. "',\z
                                       octaves = 3,\z
                                       persistence = 0.5,\z
                                       input_scale = 1/250,\z
                                       output_scale = " .. amplitude .. "}"
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
    expression = radius_wobble("simulacruis_radius_wobble", 50)
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_1",
    expression = radius_wobble("simulacruis_radius_wobble_zone_1", wobble_amplitude_1)
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_2",
    expression = radius_wobble("simulacruis_radius_wobble_zone_2", wobble_amplitude_2)
  },
  {
    type = "noise-expression",
    name = "simulacruis_wobbled_distance_zone_3",
    expression = radius_wobble("simulacruis_radius_wobble_zone_3", wobble_amplitude_3)
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
    expression = "clamp((simulacruis_wobbled_distance_zone_1 - " .. (zone_1_radius - transition_1 / 2) .. ") / " .. transition_1 .. ", 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_step_2",
    expression = "clamp((simulacruis_wobbled_distance_zone_2 - " .. (zone_2_radius - transition_2 / 2) .. ") / " .. transition_2 .. ", 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_step_3",
    expression = "clamp((simulacruis_wobbled_distance_zone_3 - " .. (zone_3_radius - transition_3 / 2) .. ") / " .. transition_3 .. ", 0, 1)"
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
