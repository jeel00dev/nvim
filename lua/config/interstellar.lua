-- Start-screen renderer. Every terminal cell is two square pixels drawn with "▀"
-- (top pixel = foreground colour, bottom pixel = background colour).
--
-- Pipeline per frame, all in linear RGB:
--   background (lensed nebula, galaxy, stars)  x  scene transmission (shadow, dust)
--   + scene emission (disk, jets, glow)        + the ship (in front of or behind it)
--   -> tone map -> 12-bit colour (16 levels per channel, gamma 2, ordered dither).
-- Colours become highlight groups lazily: one fg-only and one bg-only group per
-- colour, stacked per chunk, so at most 2 x 4096 groups can ever exist.
-- Anything static (nebula, lensing, disk geometry) is cached per window size.
local M = {}
local sin, cos, sqrt, exp, floor, min, max =
   math.sin, math.cos, math.sqrt, math.exp, math.floor, math.min, math.max

M.names = { "blackhole", "quasar" }

-------------------------------------------------------------------------------------
-- Shared helpers (also used by the scenes and the ship)
-------------------------------------------------------------------------------------
function M.smoothstep(a, b, x)
   local t = max(0, min(1, (x - a) / (b - a)))
   return t * t * (3 - 2 * t)
end

local function fraction(x)
   return x - floor(x)
end
M.fraction = fraction

local function hash(x, y)
   return fraction(sin(x * 127.1 + y * 311.7) * 43758.5453)
end

-- Smooth value noise and fractal noise in [0, 1].
local function noise(x, y)
   local ix, iy = floor(x), floor(y)
   local fx, fy = x - ix, y - iy
   fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
   local a, b = hash(ix, iy), hash(ix + 1, iy)
   local c, d = hash(ix, iy + 1), hash(ix + 1, iy + 1)
   return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy
end

local function fbm(x, y, octaves)
   local sum, amp, norm = 0, 0.5, 0
   for _ = 1, octaves do
      sum, norm = sum + noise(x, y) * amp, norm + amp
      x, y, amp = x * 2.03 + 17.1, y * 2.03 - 9.7, amp * 0.5
   end
   return sum / norm
end
M.fbm = fbm

-------------------------------------------------------------------------------------
-- Colours and highlight groups
-------------------------------------------------------------------------------------
local LEVEL = {}
for i = 0, 15 do
   LEVEL[i] = floor((i / 15) ^ 2 * 255 + 0.5)
end
local fg_groups, bg_groups = {}, {}

local function hex(key)
   return string.format(
      "#%02x%02x%02x",
      LEVEL[floor(key / 256)],
      LEVEL[floor(key / 16) % 16],
      LEVEL[key % 16]
   )
end
local function fg_group(key)
   local name = fg_groups[key]
   if not name then
      name = "IF" .. key
      vim.api.nvim_set_hl(0, name, { fg = hex(key) })
      fg_groups[key] = name
   end
   return name
end
local function bg_group(key)
   local name = bg_groups[key]
   if not name then
      name = "IB" .. key
      vim.api.nvim_set_hl(0, name, { bg = hex(key) })
      bg_groups[key] = name
   end
   return name
end

function M.reset_highlights()
   fg_groups, bg_groups = {}, {}
end

-------------------------------------------------------------------------------------
-- Static view: layout, lensed background, scene geometry
-------------------------------------------------------------------------------------
local scenes = require("config.interstellar_scenes")
local view

-- Stellar colours from hot blue to cool red.
local STAR_COLORS = {
   { 0.70, 0.80, 1.00 },
   { 0.85, 0.90, 1.00 },
   { 1.00, 1.00, 1.00 },
   { 1.00, 0.95, 0.82 },
   { 1.00, 0.84, 0.62 },
   { 1.00, 0.70, 0.52 },
}

local function build(pw, ph, name)
   local scene = scenes[name]
   local v = { pw = pw, ph = ph, n = pw * ph, name = name }
   scene.layout(v) -- sets cx, cy, R (pixels per unit), lens, nebula, galaxy, key light, exposure
   local R, cx, cy, lens2 = v.R, v.cx, v.cy, v.lens * v.lens
   local bgR, bgG, bgB = {}, {}, {}
   local neb = v.nebula -- { colour a, colour b, colour c, strength }
   local galaxy = v.galaxy -- { x, y, size, angle } in pixels
   local ga, gs = cos(galaxy[4]), sin(galaxy[4])
   for y = 0, ph - 1 do
      for x = 0, pw - 1 do
         local i = y * pw + x + 1
         local u, w = (x + 0.5 - cx) / R, (y + 0.5 - cy) / R
         -- Point-lens mapping: where on the sky this pixel's light comes from.
         local k = 1 - lens2 / max(u * u + w * w, 1e-4)
         local su, sw = u * k, w * k
         local nx, ny = su * 0.55 + 7.3, sw * 0.55 + 3.1
         local density = fbm(nx, ny, 5)
         local hue = fbm(nx * 0.6 - 4.2, ny * 0.6 + 8.8, 3)
         local wisps = fbm(nx * 2.2 + 1.7, ny * 2.2 - 3.3, 3)
         local dark = 1 - 0.7 * M.smoothstep(0.52, 0.72, fbm(nx * 1.4 - 9.1, ny * 1.4 + 2.2, 3))
         local glow = M.smoothstep(0.4, 0.82, density) ^ 1.6 * (0.5 + 0.5 * wisps) * neb[4] * dark
         local h1, h2 = M.smoothstep(0.3, 0.7, hue), M.smoothstep(0.55, 0.85, wisps) * 0.6
         local a, b, c = neb[1], neb[2], neb[3]
         local r = ((a[1] + (b[1] - a[1]) * h1) * (1 - h2) + c[1] * h2) * glow
         local g = ((a[2] + (b[2] - a[2]) * h1) * (1 - h2) + c[2] * h2) * glow
         local bl = ((a[3] + (b[3] - a[3]) * h1) * (1 - h2) + c[3] * h2) * glow
         -- A faint, distant spiral galaxy.
         local gx, gy = (su * R + cx - galaxy[1]) / galaxy[3], (sw * R + cy - galaxy[2]) / galaxy[3]
         gx, gy = gx * ga + gy * gs, (-gx * gs + gy * ga) * 2.6
         local gr = sqrt(gx * gx + gy * gy)
         if gr < 1.6 then
            local arms = 0.5 + 0.5 * sin(2 * math.atan2(gy, gx) - 5.5 * gr)
            local core = exp(-gr * gr * 30) * 0.55
            local disk = exp(-gr * 2.4) * arms * 0.2
            r, g, bl =
               r + core + disk * 0.7, g + core * 0.85 + disk * 0.75, bl + core * 0.6 + disk * 1.05
         end
         bgR[i], bgG[i], bgB[i] = r, g, bl
      end
   end
   v.bgR, v.bgG, v.bgB = bgR, bgG, bgB
   v.transmit, v.block = {}, {}
   for i = 1, v.n do
      v.transmit[i], v.block[i] = 1, 0
   end
   v.emR, v.emG, v.emB = {}, {}, {}
   scene.build(v) -- fills transmit/block, static emission and animated samples

   -- Stars: many faint ones as fine glyphs, a few bright ones as pixels with spikes.
   v.stars = {}
   for i = 1, max(12, floor(v.n / 140)) do
      local depth = hash(i, 3.1)
      v.stars[i] = {
         x = hash(i, 1.3) * pw,
         y = hash(i, 7.7) * ph,
         depth = depth,
         phase = i * 2.39996,
         color = STAR_COLORS[1 + floor(hash(i, 5.9) * #STAR_COLORS)],
         bright = depth > 0.955 and (0.8 + (depth - 0.955) * 10) or 0,
      }
   end
   v.dither = { 0.3, 0.55, 0.7, 0.45 }
   v.R_, v.G_, v.B_, v.keys = {}, {}, {}, {}
   return v
end

-------------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------------
local function blend(R, G, B, pixels)
   for i, p in pairs(pixels) do
      local a = p[4]
      R[i], G[i], B[i] =
         R[i] * (1 - a) + p[1] * a, G[i] * (1 - a) + p[2] * a, B[i] * (1 - a) + p[3] * a
   end
end

-- Colour key for "#rrggbb", used for text drawn into the frame.
function M.key(hex)
   local key = 0
   for i, shift in ipairs({ 256, 16, 1 }) do
      local c = tonumber(hex:sub(i * 2, i * 2 + 1), 16) / 255
      key = key + min(15, floor(sqrt(c) * 15 + 0.5)) * shift
   end
   return key
end

-- Returns rows of virt_text chunks plus a signature string per row.
-- `text` (optional) = { row = 0-based cell row, col = cell column, cells = { {char, key}, ... } }
-- is drawn into the frame, keeping the sky behind each character.
function M.frame(width, height, time, name, text)
   local pw, ph = width, height * 2
   local v = view
   if not v or v.pw ~= pw or v.ph ~= ph or v.name ~= name then
      v = build(pw, ph, name)
      view = v
   end
   local n = v.n
   local R, G, B = v.R_, v.G_, v.B_
   local bgR, bgG, bgB, T, block = v.bgR, v.bgG, v.bgB, v.transmit, v.block
   local eR, eG, eB = v.emR, v.emG, v.emB
   for i = 1, n do
      R[i], G[i], B[i] = bgR[i], bgG[i], bgB[i]
   end
   scenes[name].draw(v, time) -- writes eR/eG/eB

   -- Stars, lensed: a primary image and, near the hole, a faint secondary one.
   local glyphs = {}
   local cx, cy, unit, lens = v.cx, v.cy, v.R, v.lens
   local function add(x, y, amount, color)
      if x >= 0 and y >= 0 and x < pw and y < ph then
         local j = y * pw + x + 1
         local a = amount * (1 - block[j])
         R[j], G[j], B[j] = R[j] + color[1] * a, G[j] + color[2] * a, B[j] + color[3] * a
      end
   end
   local function star(px, py, value, color, bright)
      local x, y = floor(px), floor(py)
      if x < 0 or y < 0 or x >= pw or y >= ph then
         return
      end
      local i = y * pw + x + 1
      if T[i] * (1 - block[i]) < 0.3 then
         return
      end
      if bright then
         add(x, y, value * 1.6, color)
         for d = 1, 3 do
            local a = value * ({ 0.35, 0.12, 0.04 })[d]
            add(x + d, y, a, color)
            add(x - d, y, a, color)
            add(x, y + d, a, color)
            add(x, y - d, a, color)
         end
      else
         local cell = floor(y / 2) * pw + x + 1
         local g = glyphs[cell]
         if not g or g.value < value then
            glyphs[cell] = { value = value, color = color }
         end
      end
   end
   for _, s in ipairs(v.stars) do
      local x = (s.x - time * (0.15 + 0.6 * s.depth)) % pw
      local u, w = (x - cx) / unit, (s.y - cy) / unit
      local r = sqrt(u * u + w * w)
      local twinkle = 0.75 + 0.25 * sin(time * (1.1 + s.depth) + s.phase)
      local bright = s.bright > 0
      local value = (bright and s.bright or (0.25 + 0.6 * s.depth)) * twinkle
      local root = sqrt(r * r + 4 * lens * lens)
      local scale = (r + root) / 2 / max(r, 1e-6)
      star(cx + u * scale * unit, cy + w * scale * unit, value, s.color, bright)
      if r < 3 then
         local inner = (r - root) / 2 / max(r, 1e-6)
         star(cx + u * inner * unit, cy + w * inner * unit, value * 0.5 / (0.5 + r), s.color, false)
      end
   end

   -- The ship is drawn behind the scene (its light and shadow cover it) or in front.
   local ship = require("config.interstellar_ship").draw(v, time)
   if ship and not ship.front then
      blend(R, G, B, ship.pixels)
   end
   for i = 1, n do
      local er, eg, eb = eR[i], eG[i], eB[i]
      local t = T[i] * (1 - min(1, (er + eg + eb) * 0.9))
      R[i], G[i], B[i] = R[i] * t + er, G[i] * t + eg, B[i] * t + eb
   end
   if ship then
      if ship.front then
         blend(R, G, B, ship.pixels)
      end
      for i, p in pairs(ship.glow) do
         R[i], G[i], B[i] = R[i] + p[1], G[i] + p[2], B[i] + p[3]
      end
   end

   -- Tone map and quantise to 12-bit colour keys.
   local key, dither, exposure = v.keys, v.dither, v.exposure
   for y = 0, ph - 1 do
      local row = y * pw
      local dy = (y % 2) * 2 + 1
      for x = 0, pw - 1 do
         local i = row + x + 1
         local d = dither[dy + x % 2]
         local r = min(15, floor(sqrt(1 - exp(-R[i] * exposure)) * 15 + d))
         local g = min(15, floor(sqrt(1 - exp(-G[i] * exposure)) * 15 + d))
         local b = min(15, floor(sqrt(1 - exp(-B[i] * exposure)) * 15 + d))
         key[i] = r * 256 + g * 16 + b
      end
   end

   -- Assemble rows, merging runs of identical cells into one chunk.
   local rows, signatures = {}, {}
   local covered = ship and ship.pixels or {}
   local function level(c, value)
      return min(15, floor(sqrt(1 - exp(-c * value * 2.2)) * 15 + 0.5))
   end
   for row = 0, height - 1 do
      local overlay = text and text.row == row and text
      local chunks, sig = {}, {}
      local text, cur_char, cur_fg, cur_bg = {}, nil, nil, nil
      local function flush()
         local s = table.concat(text)
         chunks[#chunks + 1] =
            { s, cur_fg and { bg_group(cur_bg), fg_group(cur_fg) } or bg_group(cur_bg) }
         sig[#sig + 1] = s .. cur_bg .. ":" .. (cur_fg or "")
      end
      for x = 0, pw - 1 do
         local top, bottom = row * 2 * pw + x + 1, (row * 2 + 1) * pw + x + 1
         local kt, kb = key[top], key[bottom]
         local char, fg, bg
         local g = glyphs[row * pw + x + 1]
         local o = overlay and overlay.cells[x - overlay.col + 1]
         if o then
            local r = floor(kt / 256) + floor(kb / 256)
            local gg = floor(kt / 16) % 16 + floor(kb / 16) % 16
            local b = kt % 16 + kb % 16
            -- Darken the sky under the text a little so it stays readable.
            char, fg, bg = o[1], o[2], floor(r * 0.3) * 256 + floor(gg * 0.3) * 16 + floor(b * 0.3)
         elseif g and not covered[top] and not covered[bottom] and eR[top] + eR[bottom] < 0.03 then
            local c, val = g.color, g.value
            fg = level(c[1], val) * 256 + level(c[2], val) * 16 + level(c[3], val)
            char, bg = val > 0.62 and "•" or (val > 0.38 and "·" or "."), kb
         elseif kt == kb then
            char, bg = " ", kb
         else
            char, fg, bg = "▀", kt, kb
         end
         if char ~= cur_char or fg ~= cur_fg or bg ~= cur_bg then
            if cur_char then
               flush()
            end
            text, cur_char, cur_fg, cur_bg = { char }, char, fg, bg
         else
            text[#text + 1] = char
         end
      end
      flush()
      rows[row + 1] = chunks
      signatures[row + 1] = table.concat(sig, "|")
   end
   return rows, signatures
end

return M
