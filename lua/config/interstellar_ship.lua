-- The Endurance: twelve modules (four in gold thermal foil) joined by tubes, four
-- spokes, an octagonal hub with a docked Ranger. Rasterised in 3D at 2x2 samples per
-- pixel with depth testing, then lit per sample: warm key light from the scene's
-- centre, cool fill, specular highlights, rim light, bevelled panel seams and lit
-- windows. Navigation lights blink and thrusters fire now and then.
--
-- It orbits the scene centre: in front of the disk on the near side, hidden behind
-- the shadow and light on the far side.
local Ship = { orbit_seconds = 72, spin_seconds = 22 }
local sin, cos, sqrt, floor, min, max, abs, pi =
   math.sin, math.cos, math.sqrt, math.floor, math.min, math.max, math.abs, math.pi

local function fraction(x)
   return x - floor(x)
end

-- r, g, b, specular strength, glossiness, panel seams
local MATERIALS = {
   hull = { 0.80, 0.80, 0.78, 0.35, 24, true },
   panel = { 0.64, 0.65, 0.64, 0.25, 16, true },
   foil = { 0.92, 0.68, 0.28, 0.9, 40, false },
   dark = { 0.20, 0.22, 0.25, 0.2, 10, false },
   white = { 0.92, 0.92, 0.90, 0.45, 30, true },
}
local UV = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }
local SIGNS = {
   { -1, -1, -1 },
   { 1, -1, -1 },
   { 1, 1, -1 },
   { -1, 1, -1 },
   { -1, -1, 1 },
   { 1, -1, 1 },
   { 1, 1, 1 },
   { -1, 1, 1 },
}

function Ship.draw(v, time)
   local pw, ph, R = v.pw, v.ph, v.R
   if pw < 48 or ph < 28 then
      return
   end

   -- Orbit: an inclined ellipse around the centre. near > 0 means in front of it.
   local phase = 2 * pi * time / Ship.orbit_seconds + 0.55
   local near = sin(phase)
   local cx = v.cx + cos(phase) * 3.75 * R
   local cy = v.cy + near * 1.3 * R - cos(phase) * 0.18 * R
   local size = R * v.ship_scale * (1 + 0.28 * near)

   -- Orientation: spin about the ring axis, pitch to show the ring open, gentle roll.
   local spin = 2 * pi * time / Ship.spin_seconds
   local pitch = 0.98 + 0.06 * sin(phase * 2)
   local roll = -0.32 + 0.12 * cos(phase)
   local cs, ss, cp, sp, cr, sr = cos(spin), sin(spin), cos(pitch), sin(pitch), cos(roll), sin(roll)
   local function rotate(x, y, z)
      x, y = x * cs - y * ss, x * ss + y * cs
      y, z = y * cp - z * sp, y * sp + z * cp
      return x * cr - y * sr, x * sr + y * cr, z
   end

   -- Lights. The camera looks along +z, so -z points at the viewer.
   local key = v.key
   local lx, ly = v.cx - cx, v.cy - cy
   local ll = sqrt(lx * lx + ly * ly) + 1e-6
   lx, ly = lx / ll * 0.8, ly / ll * 0.8
   local lz = -0.6
   local fx, fy, fz = -lx * 0.6, -ly * 0.6 - 0.5, -0.6
   local fl = sqrt(fx * fx + fy * fy + fz * fz)
   fx, fy, fz = fx / fl, fy / fl, fz / fl
   local hx, hy, hz = lx, ly, lz - 1
   local hl = sqrt(hx * hx + hy * hy + hz * hz)
   hx, hy, hz = hx / hl, hy / hl, hz / hl

   local sw, sh = pw * 2, ph * 2
   local depth, sr_, sg_, sb_ = {}, {}, {}, {}

   local function project(x, y, z)
      local X, Y, Z = rotate(x, y, z)
      local f = 1 / (1 + Z * 0.12)
      return (cx + X * size * f) * 2, (cy + Y * size * f) * 2, Z
   end

   -- Flat lighting of one face; per-sample detail is applied while rasterising.
   local function light(nx, ny, nz, m)
      local diffuse = max(0, nx * lx + ny * ly + nz * lz)
      local fill = max(0, nx * fx + ny * fy + nz * fz)
      local spec = max(0, nx * hx + ny * hy + nz * hz) ^ m[5] * m[4]
      local k = diffuse * 1.35 + (1 - abs(nz)) ^ 2 * 0.3
      return m[1] * (0.03 + key[1] * k + 0.1 * fill) + key[1] * spec,
         m[2] * (0.035 + key[2] * k + 0.13 * fill) + key[2] * spec,
         m[3] * (0.05 + key[3] * k + 0.22 * fill) + key[3] * spec
   end

   local windows = v.windows
   local function triangle(a, b, c, ua, ub, uc, face)
      local area = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
      if abs(area) < 0.01 then
         return
      end
      local x0 = max(0, floor(min(a[1], b[1], c[1])))
      local x1 = min(sw - 1, floor(max(a[1], b[1], c[1])))
      local y0 = max(0, floor(min(a[2], b[2], c[2])))
      local y1 = min(sh - 1, floor(max(a[2], b[2], c[2])))
      local fr, fg, fb, panels, lit = face[1], face[2], face[3], face[4], face[5]
      for y = y0, y1 do
         local py = y + 0.5
         for x = x0, x1 do
            local px = x + 0.5
            local w0 = ((b[1] - px) * (c[2] - py) - (b[2] - py) * (c[1] - px)) / area
            local w1 = ((c[1] - px) * (a[2] - py) - (c[2] - py) * (a[1] - px)) / area
            local w2 = 1 - w0 - w1
            if w0 >= 0 and w1 >= 0 and w2 >= 0 then
               local z = w0 * a[3] + w1 * b[3] + w2 * c[3]
               local k = y * sw + x
               if not depth[k] or z < depth[k] then
                  local u = w0 * ua[1] + w1 * ub[1] + w2 * uc[1]
                  local t = w0 * ua[2] + w1 * ub[2] + w2 * uc[2]
                  local edge = min(u, 1 - u, t, 1 - t)
                  local f = edge < 0.06 and 0.62 or (edge < 0.12 and 1.15 or 1)
                  if panels and (fraction(u * 3) < 0.07 or fraction(t * 2) < 0.07) then
                     f = f * 0.7
                  end
                  depth[k] = z
                  local column = fraction(u * 4)
                  if
                     lit
                     and t > 0.36
                     and t < 0.64
                     and column > 0.3
                     and column < 0.7
                     and edge > 0.1
                  then
                     sr_[k], sg_[k], sb_[k] = windows[1] * 1.4, windows[2] * 1.4, windows[3] * 1.4
                  else
                     sr_[k], sg_[k], sb_[k] = fr * f, fg * f, fb * f
                  end
               end
            end
         end
      end
   end

   -- Box centred at (x, y, z) with in-plane axes a and b (the third axis is the ring
   -- axis). Faces: +a (outer), -a, +b, -b, +z (top), -z.
   local function box(x, y, z, a, b, ha, hb, hz, m, windows_outside)
      local corners = {}
      for i, s in ipairs(SIGNS) do
         corners[i] = {
            project(
               x + a[1] * s[1] * ha + b[1] * s[2] * hb,
               y + a[2] * s[1] * ha + b[2] * s[2] * hb,
               z + s[3] * hz
            ),
         }
      end
      local faces = {
         { 2, 3, 7, 6, a[1], a[2], 0, windows_outside },
         { 1, 5, 8, 4, -a[1], -a[2], 0 },
         { 3, 4, 8, 7, b[1], b[2], 0 },
         { 1, 2, 6, 5, -b[1], -b[2], 0 },
         { 5, 6, 7, 8, 0, 0, 1 },
         { 1, 4, 3, 2, 0, 0, -1 },
      }
      for _, f in ipairs(faces) do
         local nx, ny, nz = rotate(f[5], f[6], f[7])
         if nz < 0.05 then
            local r, g, bl = light(nx, ny, nz, m)
            local face = { r, g, bl, m[6], f[8] }
            local p1, p2, p3, p4 = corners[f[1]], corners[f[2]], corners[f[3]], corners[f[4]]
            triangle(p1, p2, p3, UV[1], UV[2], UV[3], face)
            triangle(p1, p3, p4, UV[1], UV[3], UV[4], face)
         end
      end
   end

   -- Hub (an octagon from two boxes) with a docked Ranger on top.
   local q = { cos(0.6), sin(0.6) }
   local qn = { -q[2], q[1] }
   box(0, 0, 0, { 1, 0 }, { 0, 1 }, 0.12, 0.12, 0.16, MATERIALS.hull)
   box(0, 0, 0, { 0.7071, 0.7071 }, { -0.7071, 0.7071 }, 0.12, 0.12, 0.155, MATERIALS.panel)
   box(0, 0, 0.21, q, qn, 0.2, 0.055, 0.035, MATERIALS.white)
   box(0, 0, 0.25, q, qn, 0.07, 0.035, 0.012, MATERIALS.dark)
   -- Spokes.
   for k = 0, 3 do
      local a = k * pi / 2 + pi / 4
      box(
         cos(a) * 0.5,
         sin(a) * 0.5,
         0,
         { cos(a), sin(a) },
         { -sin(a), cos(a) },
         0.37,
         0.022,
         0.022,
         MATERIALS.dark
      )
   end
   -- Modules and the tubes between them.
   for m = 0, 11 do
      local a = m * pi / 6
      local radial, tangent = { cos(a), sin(a) }, { -sin(a), cos(a) }
      local foil = m % 3 == 0
      local material = foil and MATERIALS.foil or (m % 2 == 0 and MATERIALS.hull or MATERIALS.panel)
      box(
         radial[1],
         radial[2],
         0,
         radial,
         tangent,
         0.12,
         0.15,
         foil and 0.13 or 0.1,
         material,
         not foil
      )
      local t = a + pi / 12
      local tr, tt = { cos(t), sin(t) }, { -sin(t), cos(t) }
      box(tr[1] * 0.99, tr[2] * 0.99, 0, tr, tt, 0.035, 0.12, 0.035, MATERIALS.dark)
   end

   -- Resolve samples into pixels: average colour, coverage as alpha.
   local acc = {}
   for k in pairs(depth) do
      local p = floor(floor(k / sw) / 2) * pw + floor((k % sw) / 2) + 1
      local c = acc[p]
      if not c then
         acc[p] = { sr_[k], sg_[k], sb_[k], 1 }
      else
         c[1], c[2], c[3], c[4] = c[1] + sr_[k], c[2] + sg_[k], c[3] + sb_[k], c[4] + 1
      end
   end
   local pixels = {}
   for p, c in pairs(acc) do
      local n = c[4]
      pixels[p] = { c[1] / n, c[2] / n, c[3] / n, n / 4 }
   end

   -- Additive lights: navigation lights, strobe and thruster plumes.
   local front = near > -0.1
   local glow = {}
   local T, eR, eG, eB = v.transmit, v.emR, v.emG, v.emB
   local function point(x, y, z, r, g, b, spread)
      local X, Y = project(x, y, z)
      X, Y = floor(X / 2), floor(Y / 2)
      for oy = -spread, spread do
         for ox = -spread, spread do
            local xx, yy = X + ox, Y + oy
            if xx >= 0 and yy >= 0 and xx < pw and yy < ph then
               local i = yy * pw + xx + 1
               if front or (T[i] > 0.5 and eR[i] + eG[i] + eB[i] < 0.3) then
                  local f = (ox == 0 and oy == 0) and 1 or 0.18 / (abs(ox) + abs(oy))
                  local c = glow[i] or { 0, 0, 0 }
                  c[1], c[2], c[3] = c[1] + r * f, c[2] + g * f, c[3] + b * f
                  glow[i] = c
               end
            end
         end
      end
   end
   local beat = time % 1.2
   if beat < 0.25 then -- red on one side, green on the other
      point(cos(pi / 2) * 1.13, sin(pi / 2) * 1.13, 0, 1.6, 0.1, 0.08, 1)
   elseif beat < 0.5 then
      point(cos(3 * pi / 2) * 1.13, sin(3 * pi / 2) * 1.13, 0, 0.1, 1.5, 0.3, 1)
   end
   if time % 2.4 < 0.08 then
      point(0, 0, -0.18, 2, 2, 2, 2)
   end
   local burn = time % 14
   if burn < 1.6 then
      local strength = sin(burn / 1.6 * pi)
      for _, m in ipairs({ 0, 6 }) do
         local a = m * pi / 6
         for step = 1, 10 do
            local d = step / 10
            local e = strength * (1 - d) ^ 1.3
            local x = cos(a) + sin(a) * (0.16 + d * 0.55)
            local y = sin(a) - cos(a) * (0.16 + d * 0.55)
            point(x, y, 0, 0.5 * e, 0.75 * e, 1.3 * e, step < 4 and 1 or 0)
         end
      end
   end
   return { front = front, pixels = pixels, glow = glow }
end

return Ship
