-- The two start-screen scenes. Each scene has:
--   layout(v)  size and colours (v.R = pixels per unit length, v.cx/v.cy = centre)
--   build(v)   static work per window size: shadow, disk sample lists, glow, planet
--   draw(v, t) fills v.emR/emG/emB with this frame's emitted light
-- Lengths are in units of v.R; the black hole's shadow has radius 1 (black hole) or
-- 0.3 (quasar, whose disk is far larger than its horizon).
local S = {}
local sin, cos, sqrt, exp, atan2, floor, min, max, abs, log =
   math.sin,
   math.cos,
   math.sqrt,
   math.exp,
   math.atan2,
   math.floor,
   math.min,
   math.max,
   math.abs,
   math.log
local core -- config.interstellar (helpers), loaded lazily to avoid a require cycle

local function smooth(a, b, x)
   return core.smoothstep(a, b, x)
end

-- Piecewise-linear colour ramp: stops = { {t, r, g, b}, ... }.
local function gradient(stops, t)
   t = max(0, min(1, t))
   local k = 1
   while k < #stops - 1 and t > stops[k + 1][1] do
      k = k + 1
   end
   local a, b = stops[k], stops[k + 1]
   local f = (t - a[1]) / (b[1] - a[1])
   return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f
end

-- Rotating disk samples: flat arrays so the per-frame loop stays allocation free.
local function samples()
   return { idx = {}, energy = {}, r = {}, g = {}, b = {}, lr = {}, angle = {}, speed = {} }
end

local function add_sample(d, index, energy, r, g, b, rho, angle, speed)
   if energy > 0.004 then
      local n = #d.idx + 1
      d.idx[n], d.energy[n], d.r[n], d.g[n], d.b[n] = index, energy, r, g, b
      d.lr[n], d.angle[n], d.speed[n] = log(rho), angle, speed
   end
end

-- Turbulent, sheared texture with bright clumps.
local function texture(a, lr)
   local base = 0.6
      + 0.17 * sin(5 * a + 7 * lr)
      + 0.09 * sin(13 * a - 19 * lr + 1.7)
      + 0.05 * sin(31 * a + 4 * lr + 0.6)
      + 0.04 * sin(61 * a - 47 * lr + 2.1)
   local clump = max(0, sin(3 * a + 11 * lr + 0.9)) ^ 10 * 0.55
      + max(0, sin(7 * a - 5 * lr + 2.6)) ^ 14 * 0.35
   return base + clump
end

-- Adds the rotating disk to the emission buffers. Two copies of the texture
-- cross-fade so differential rotation never winds the pattern into noise.
local FADE = 36
local function draw_disk(v, d, time)
   local eR, eG, eB = v.emR, v.emG, v.emB
   local t1 = time % FADE
   local t2 = (time + FADE / 2) % FADE
   local w1 = 1 - abs(2 * t1 / FADE - 1)
   local w2 = 1 - w1
   local idx, energy, cr, cg, cb, lr, angle, speed =
      d.idx, d.energy, d.r, d.g, d.b, d.lr, d.angle, d.speed
   for n = 1, #idx do
      local a, l, s = angle[n], lr[n], speed[n]
      local e = energy[n] * (w1 * texture(a + s * t1, l) + w2 * texture(a + s * t2, l))
      local i = idx[n]
      eR[i], eG[i], eB[i] = eR[i] + cr[n] * e, eG[i] + cg[n] * e, eB[i] + cb[n] * e
   end
end

local function copy_static(v)
   local eR, eG, eB, sR, sG, sB = v.emR, v.emG, v.emB, v.sR, v.sG, v.sB
   for i = 1, v.n do
      eR[i], eG[i], eB[i] = sR[i], sG[i], sB[i]
   end
end

local function zeros(v)
   local r, g, b = {}, {}, {}
   for i = 1, v.n do
      r[i], g[i], b[i] = 0, 0, 0
   end
   return r, g, b
end

-- Relativistic beaming: the approaching side (left) is brighter and bluer.
local function beam(approach, strength, r, g, b)
   local boost = (1 + strength * approach) ^ 2
   local blue = max(0, approach) * 0.15
   local red = 1 + 0.4 * min(0, approach)
   return (r + (1 - r) * blue) * boost,
      (g + (1 - g) * blue) * red * boost,
      (b + (1 - b) * blue) * red * red * boost
end

-------------------------------------------------------------------------------------
-- Black hole (Gargantua): edge-on disk, lensed halo, photon ring, ocean planet.
-------------------------------------------------------------------------------------
local hole = {}
S.blackhole = hole

local HOT = {
   { 0.00, 1.00, 0.95, 0.85 },
   { 0.10, 1.00, 0.78, 0.45 },
   { 0.28, 1.00, 0.52, 0.14 },
   { 0.55, 0.92, 0.28, 0.05 },
   { 1.00, 0.55, 0.08, 0.02 },
}

function hole.layout(v)
   v.R = max(3, min(v.pw / 9.6, v.ph / 3.9))
   v.cx, v.cy = v.pw * 0.5, v.ph * 0.48
   v.lens = 1.3
   v.nebula = { { 0.10, 0.16, 0.45 }, { 0.32, 0.10, 0.42 }, { 0.05, 0.34, 0.38 }, 0.22 }
   v.galaxy = { v.pw * 0.85, v.ph * 0.15, v.R * 0.9, 0.5 }
   v.key = { 1.0, 0.72, 0.44 }
   v.windows = { 1.0, 0.82, 0.52 }
   v.exposure = 2.3
   v.ship_scale = 0.62
end

local DISK_IN, DISK_OUT, INCLINE, TILT, SPIN = 1.3, 4.7, 0.14, 0.045, 0.6

local function disk_profile(rho, inner)
   if rho <= inner or rho >= DISK_OUT then
      return 0
   end
   return smooth(inner, inner + 0.18, rho)
      * (inner / rho) ^ 1.7
      * (1 - smooth(DISK_OUT - 1.6, DISK_OUT, rho))
      * (0.84 + 0.1 * sin(rho * 19) + 0.06 * sin(rho * 53 + 1.3))
end

local function planet(v)
   local px, py, pr = v.pw * 0.13, v.ph * 0.2, v.R * 0.45
   local lx, ly = v.cx - px, v.cy - py
   local ll = sqrt(lx * lx + ly * ly)
   lx, ly = lx / ll * 0.9, ly / ll * 0.9
   local lz = -sqrt(1 - 0.81)
   local bgR, bgG, bgB, block = v.bgR, v.bgG, v.bgB, v.block
   for y = max(0, floor(py - pr * 1.3)), min(v.ph - 1, floor(py + pr * 1.3)) do
      for x = max(0, floor(px - pr * 1.3)), min(v.pw - 1, floor(px + pr * 1.3)) do
         local i = y * v.pw + x + 1
         local dx, dy = (x + 0.5 - px) / pr, (y + 0.5 - py) / pr
         local d = sqrt(dx * dx + dy * dy)
         local side = max(0, (dx * lx + dy * ly) / max(d, 1e-6))
         if d < 1 then
            local nz = sqrt(1 - d * d)
            local diffuse = max(0, dx * lx + dy * ly - nz * lz)
            -- Ocean world with long cloud bands, warmly lit by the disk.
            local lon, lat = dx / (nz + 0.35), dy
            local clouds = smooth(0.5, 0.78, core.fbm(lon * 2.2 + 3.3, lat * 7.5 - 1.1, 4))
            local swell = core.fbm(lon * 5 + 9, lat * 5, 3) * 0.08
            local r = (0.04 + swell * 0.3) * (1 - clouds) + 0.86 * clouds
            local g = (0.20 + swell) * (1 - clouds) + 0.88 * clouds
            local b = (0.32 + swell) * (1 - clouds) + 0.92 * clouds
            local light = 0.02 + 1.15 * diffuse
            local rim = (1 - nz) ^ 2.5 * (0.15 + diffuse)
            r = r * light * 1.0 + rim * 0.25
            g = g * light * 0.86 + rim * 0.55
            b = b * light * 0.72 + rim * 1.0
            local a = min(1, (1 - d) * pr * 1.6)
            bgR[i] = bgR[i] * (1 - a) + r * a
            bgG[i] = bgG[i] * (1 - a) + g * a
            bgB[i] = bgB[i] * (1 - a) + b * a
            block[i] = a
         elseif d < 1.3 then
            -- Thin atmosphere glow on the lit limb.
            local glow = exp(-(d - 1) * 22) * (0.15 + side) * 0.6
            bgR[i], bgG[i], bgB[i] = bgR[i] + glow * 0.25, bgG[i] + glow * 0.5, bgB[i] + glow
         end
      end
   end
end

function hole.build(v)
   core = core or require("config.interstellar")
   local pw, ph, R, cx, cy = v.pw, v.ph, v.R, v.cx, v.cy
   local sR, sG, sB = zeros(v)
   local d = samples()
   local edge = 1 / R
   local ring_width = max(0.012, 0.55 / R)
   local ct, st = cos(TILT), sin(TILT)
   local T = v.transmit
   for y = 0, ph - 1 do
      for x = 0, pw - 1 do
         local i = y * pw + x + 1
         local u, w = (x + 0.5 - cx) / R, (y + 0.5 - cy) / R
         local r = sqrt(u * u + w * w)
         local outside = smooth(1 - edge, 1 + edge, r)
         T[i] = outside

         -- Direct image of the disk: an inclined ellipse crossing in front of the shadow.
         local xd = u * ct + w * st
         local yd = (w * ct - u * st) / INCLINE
         local rho = sqrt(xd * xd + yd * yd)
         local energy = disk_profile(rho, 1.0) * (yd > 0 and 1 or outside) * 1.2
         if energy > 0 then
            local cr, cg, cb = beam(-xd / rho, 0.5, gradient(HOT, (rho - 1) / 3.7))
            add_sample(d, i, energy, cr, cg, cb, rho, atan2(yd, xd), SPIN * rho ^ -1.5)
         end
         if r > 1 then
            -- Lensed far side: a broad halo over the top, a thin one underneath.
            local s = (w / r + 1) * 0.5
            local lrho = DISK_IN + (r - 1.025) * (4.8 + 7 * s)
            local weight = (1.4 - 0.85 * s) * smooth(1.0, 1.04, r)
            local e = disk_profile(lrho, DISK_IN) * weight
            if e > 0 then
               local cr, cg, cb = beam(-u / r, 0.45, gradient(HOT, (lrho - DISK_IN) / 3.4))
               add_sample(d, i, e, cr, cg, cb, lrho, atan2(w, u), SPIN * (lrho / DISK_IN) ^ -1.5)
            end
            -- Photon ring (white, faintly blue) and a second, fainter ring just inside.
            local ring = exp(-((r - 1.012) / ring_width) ^ 2) * 1.1
               + exp(-((r - 1.06) / ring_width) ^ 2) * 0.25
            ring = ring * (1 + 0.35 * (-u / r))
            sR[i], sG[i], sB[i] = ring * 0.95, ring * 0.97, ring
         end
         -- Bloom: warm haze around the disk band and the shadow's edge.
         local band = exp(-abs(w * ct - u * st) / 0.3) * (1 - smooth(3.5, 6, abs(xd))) * 0.05
         local halo = r > 1 and exp(-(r - 1) / 0.35) * 0.06 or 0
         local haze = (band + halo) * outside
         sR[i], sG[i], sB[i] = sR[i] + haze, sG[i] + haze * 0.55, sB[i] + haze * 0.28
      end
   end
   v.sR, v.sG, v.sB, v.disk = sR, sG, sB, d
   planet(v)
end

function hole.draw(v, time)
   copy_static(v)
   draw_disk(v, v.disk, time)
end

-------------------------------------------------------------------------------------
-- Quasar: violet-white disk, blazing core, dust torus and two relativistic jets.
-------------------------------------------------------------------------------------
local quasar = {}
S.quasar = quasar

local VIOLET = {
   { 0.00, 0.95, 0.98, 1.00 },
   { 0.12, 0.74, 0.82, 1.00 },
   { 0.30, 0.62, 0.50, 1.00 },
   { 0.55, 0.80, 0.34, 0.95 },
   { 0.80, 0.90, 0.30, 0.65 },
   { 1.00, 0.42, 0.10, 0.42 },
}
local Q_SHADOW, Q_IN, Q_OUT, Q_INCLINE, Q_TILT = 0.3, 0.42, 4.0, 0.3, 0.07

function quasar.layout(v)
   v.R = max(3, min(v.pw / 10.5, v.ph / 4.4))
   v.cx, v.cy = v.pw * 0.5, v.ph * 0.5
   v.lens = 0.5
   v.nebula = { { 0.32, 0.08, 0.45 }, { 0.10, 0.14, 0.50 }, { 0.60, 0.10, 0.48 }, 0.26 }
   v.galaxy = { v.pw * 0.13, v.ph * 0.8, v.R * 0.8, -0.4 }
   v.key = { 0.82, 0.70, 1.0 }
   v.windows = { 0.62, 0.86, 1.0 }
   v.exposure = 1.8
   v.ship_scale = 0.58
end

local function quasar_profile(rho)
   if rho <= Q_IN or rho >= Q_OUT then
      return 0
   end
   return smooth(Q_IN, Q_IN + 0.12, rho)
      * (Q_IN / rho) ^ 1.25
      * (1 - smooth(Q_OUT - 1.4, Q_OUT, rho))
      * (0.82 + 0.12 * sin(rho * 23) + 0.06 * sin(rho * 61 + 0.4))
end

function quasar.build(v)
   core = core or require("config.interstellar")
   local pw, ph, R, cx, cy = v.pw, v.ph, v.R, v.cx, v.cy
   local sR, sG, sB = zeros(v) -- constant light
   local cR, cG, cB = zeros(v) -- core light that pulses
   local d = samples()
   local jets = { idx = {}, along = {}, across = {}, width = {}, veil = {} }
   local T = v.transmit
   local ct, st = cos(Q_TILT), sin(Q_TILT)
   local edge = 1 / R
   local ring_width = max(0.01, 0.5 / R)
   local spike_width = 0.7 / R
   for y = 0, ph - 1 do
      for x = 0, pw - 1 do
         local i = y * pw + x + 1
         local u, w = (x + 0.5 - cx) / R, (y + 0.5 - cy) / R
         local r = sqrt(u * u + w * w)
         local outside = smooth(Q_SHADOW - edge, Q_SHADOW + edge, r)
         local xd = u * ct + w * st
         local along = w * ct - u * st -- along the jet axis (down is positive)
         local yd = along / Q_INCLINE
         local rho = sqrt(xd * xd + yd * yd)

         -- Disk.
         local energy = quasar_profile(rho) * (yd > 0 and 1 or outside) * 1.15
         if energy > 0 then
            local qr, qg, qb = beam(-xd / rho, 0.4, gradient(VIOLET, (rho - Q_IN) / (Q_OUT - Q_IN)))
            add_sample(d, i, energy, qr, qg, qb, rho, atan2(yd, xd), 0.9 * (rho / Q_IN) ^ -1.5)
         end
         -- Dust torus beyond the disk: darkens what lies behind it; its near half also
         -- veils the counter-jet. Its inner wall is lit by the core.
         local fuzz = core.fbm(xd * 1.6 + 4.1, yd * 0.9 - 2.3, 3)
         local torus = smooth(2.7, 3.4, rho) * (1 - smooth(4.3, 5.2, rho)) * (0.55 + 0.6 * fuzz)
         torus = min(1, torus * smooth(-0.1, 0.25, abs(along)) + torus * 0.3)
         T[i] = outside * (1 - 0.85 * torus)
         local veil = 1 - (yd > 0 and 0.85 * torus or 0) - (yd > 0 and rho < Q_OUT and 0.5 or 0)
         local wall = torus * smooth(3.6, 2.8, rho) * 0.12
         sR[i], sG[i], sB[i] = wall * 0.9, wall * 0.35, wall * 0.75

         -- Lensed ring of the far disk hugging the shadow, and the photon ring.
         if r > Q_SHADOW then
            local rn = r / Q_SHADOW
            local s = (w / r + 1) * 0.5
            local lrho = Q_IN + (rn - 1.03) * (2.6 + 4 * s)
            local e = quasar_profile(lrho) * (0.9 - 0.5 * s) * smooth(1.0, 1.05, rn)
            if e > 0 then
               local qr, qg, qb =
                  beam(-u / r, 0.4, gradient(VIOLET, (lrho - Q_IN) / (Q_OUT - Q_IN)))
               add_sample(d, i, e, qr, qg, qb, lrho, atan2(w, u), 0.9 * (lrho / Q_IN) ^ -1.5)
            end
            local ring = exp(-((r - Q_SHADOW * 1.03) / ring_width) ^ 2) * 1.6
            sR[i], sG[i], sB[i] = sR[i] + ring * 0.9, sG[i] + ring * 0.88, sB[i] + ring
         end

         -- Blazing core with a violet halo and four diffraction spikes (the shadow stays dark).
         local open = smooth(Q_SHADOW * 0.95, Q_SHADOW * 1.4, r)
         local hot = exp(-((r - Q_SHADOW) / 0.18) ^ 2) * 1.6 * open
         local halo = exp(-r / 0.55) * 0.55 * open
         local wide = exp(-r / 1.9) * 0.14
         local spikes = 0
         for k = 0, 3 do
            local a = Q_TILT + math.pi / 4 + k * math.pi / 2
            local along_s = u * cos(a) + w * sin(a)
            if along_s > 0 then
               local across = abs(-u * sin(a) + w * cos(a))
               spikes = spikes + exp(-(across / spike_width) ^ 2) / (1 + along_s * 2.2) ^ 2.2
            end
         end
         spikes = spikes * 0.55 * open
         cR[i] = hot + halo * 0.78 + wide * 0.6 + spikes * 0.88
         cG[i] = hot * 0.95 + halo * 0.62 + wide * 0.28 + spikes * 0.86
         cB[i] = hot + halo + wide * 0.95 + spikes

         -- Jet cone around the axis (both directions).
         local s_abs = abs(along)
         local width = 0.05 + 0.075 * s_abs
         if s_abs > 0.18 and abs(xd) < width * 3.5 then
            local n = #jets.idx + 1
            jets.idx[n], jets.along[n], jets.across[n], jets.width[n] = i, along, xd, width
            jets.veil[n] = along > 0 and max(0, veil) or 1
         end
      end
   end
   v.sR, v.sG, v.sB, v.cR, v.cG, v.cB, v.disk, v.jets = sR, sG, sB, cR, cG, cB, d, jets
end

function quasar.draw(v, time)
   copy_static(v)
   local eR, eG, eB = v.emR, v.emG, v.emB
   local pulse = 0.9 + 0.07 * sin(time * 1.7) + 0.03 * sin(time * 5.3)
   local cR, cG, cB = v.cR, v.cG, v.cB
   for i = 1, v.n do
      eR[i], eG[i], eB[i] = eR[i] + cR[i] * pulse, eG[i] + cG[i] * pulse, eB[i] + cB[i] * pulse
   end
   draw_disk(v, v.disk, time)

   -- Jets: a white-cyan spine inside a violet sheath, twisting, with knots racing outward.
   local j = v.jets
   local idx, along, across, width, veil = j.idx, j.along, j.across, j.width, j.veil
   for n = 1, #idx do
      local a = along[n]
      local s = abs(a)
      local w = width[n]
      local side = a < 0 and 0 or 1.3
      local twist = across[n] - 0.28 * w * sin(1.9 * s - 2.0 * time + side)
      local spine = exp(-(twist / (0.38 * w)) ^ 2)
      local sheath = exp(-(across[n] / w) ^ 2)
      local knots = max(0, sin(2.2 * s - 3.0 * time + side)) ^ 10
      local fade = smooth(0.18, 0.55, s) / (1 + 0.22 * s) ^ 1.3 * (a < 0 and 1.0 or 0.6) * veil[n]
      local core_light = spine * (0.75 + 1.3 * knots) * fade
      local glow = sheath * (0.28 + 0.25 * knots) * fade
      local magenta = sheath * min(1, s / 5) * 0.18 * fade
      local i = idx[n]
      eR[i] = eR[i] + core_light * 0.82 + glow * 0.55 + magenta * 0.9
      eG[i] = eG[i] + core_light * 0.9 + glow * 0.32 + magenta * 0.2
      eB[i] = eB[i] + core_light * 1.0 + glow * 1.0 + magenta * 0.75
   end
end

return S
