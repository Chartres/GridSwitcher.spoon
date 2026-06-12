--- === GridSwitcher ===
---
--- AltTab-style window switcher with a grid of live window previews.
---
--- * Cmd+Tab — switch between all windows
--- * Option+Tab — switch between windows of the current app
--- * Shift+Tab / tap Shift — step backwards; hold Shift to keep stepping
--- * Click or hover+release to pick with the mouse; Esc cancels
---
--- Download: https://github.com/Chartres/GridSwitcher.spoon

local obj = {}
obj.__index = obj

obj.name     = 'GridSwitcher'
obj.version  = '1.0'
obj.author   = 'Pavol Dravecky'
obj.license  = 'MIT - https://opensource.org/licenses/MIT'
obj.homepage = 'https://github.com/Chartres/GridSwitcher.spoon'

-- appearance / behaviour (override before :start())
obj.thumbW       = 320
obj.thumbH      = 200
obj.cellPad      = 10
obj.titleH       = 26
obj.iconSize     = 40
obj.margin       = 28
obj.maxWFrac     = 0.92
obj.corner       = 16
obj.bgColor      = {red=0.08, green=0.08, blue=0.09, alpha=0.96}
obj.hiliteColor  = {red=0.25, green=0.50, blue=1.00, alpha=0.92}
obj.cellColor    = {red=1, green=1, blue=1, alpha=0.06}
obj.shiftRepeat  = 0.28
obj.shiftDelay   = 0.35
obj.snapTTL      = 8       -- seconds a cached snapshot stays fresh

-- internal state
local canvas, wins, sel, session = nil, {}, 1, nil
local gridCols   = 1
local shiftTimer = nil
local snapCache  = {}      -- [win id] = {img=hs.image, t=timestamp}
local imgElem    = {}      -- [win index] = canvas element index of its image
local refreshTmr = nil

local function cellW(self) return self.thumbW + self.cellPad*2 end
local function cellH(self) return self.thumbH + self.titleH + self.cellPad*2 end

local function cellFrame(self, i)
  local r, c = math.floor((i-1)/gridCols), (i-1) % gridCols
  return {
    x = self.margin + c*cellW(self),
    y = self.margin + r*cellH(self),
    w = cellW(self), h = cellH(self),
  }
end

local function drawHighlight(self)
  if not canvas then return end
  local f = cellFrame(self, sel)
  canvas[2].frame = {x=f.x+3, y=f.y+3, w=f.w-6, h=f.h-6}
end

local function cachedSnap(w)
  local e = snapCache[w:id()]
  if e and (hs.timer.secondsSinceEpoch() - e.t) < obj.snapTTL then return e.img end
  return nil
end

-- refresh snapshots one per tick so the UI never blocks
local function asyncRefresh(self)
  local i = 0
  refreshTmr = hs.timer.doEvery(0.04, function()
    i = i + 1
    if not canvas or i > #wins then
      if refreshTmr then refreshTmr:stop(); refreshTmr = nil end
      return
    end
    local w = wins[i]
    local snap = w:snapshot()
    if snap then
      snapCache[w:id()] = {img=snap, t=hs.timer.secondsSinceEpoch()}
      local ei = imgElem[i]
      if ei and canvas then canvas[ei].image = snap end
    end
  end)
end

local function closeSwitcher(focusSelected)
  if shiftTimer  then shiftTimer:stop();  shiftTimer  = nil end
  if refreshTmr  then refreshTmr:stop();  refreshTmr  = nil end
  if canvas then canvas:delete(); canvas = nil end
  if focusSelected and wins[sel] then
    local w = wins[sel]
    if w:isMinimized() then w:unminimize() end
    w:focus()
  end
  wins, sel, session, imgElem = {}, 1, nil, {}
end

local function step(self, dir)
  if not canvas then return end
  sel = ((sel - 1 + dir) % #wins) + 1
  drawHighlight(self)
end

local function showSwitcher(self, windows)
  wins = windows
  sel  = (#wins >= 2) and 2 or 1

  local screen = hs.screen.mainScreen():frame()
  local maxCols = math.max(1, math.floor((screen.w * self.maxWFrac - self.margin*2) / cellW(self)))
  local cols = math.min(#wins, maxCols)
  if #wins > cols then
    cols = math.min(cols, math.max(2, math.ceil(math.sqrt(#wins * 1.6))))
  end
  gridCols = cols
  local rows = math.ceil(#wins / cols)

  local W = self.margin*2 + cols*cellW(self)
  local H = self.margin*2 + rows*cellH(self)

  canvas = hs.canvas.new{
    x = screen.x + (screen.w - W)/2,
    y = screen.y + (screen.h - H)/2,
    w = W, h = H,
  }

  canvas[1] = {
    type = 'rectangle', fillColor = self.bgColor,
    roundedRectRadii = {xRadius=self.corner, yRadius=self.corner},
  }
  canvas[2] = {
    type = 'rectangle', fillColor = self.hiliteColor,
    roundedRectRadii = {xRadius=12, yRadius=12},
    frame = {x=0, y=0, w=0, h=0},
  }

  local n = 2
  for i, w in ipairs(wins) do
    local f = cellFrame(self, i)
    local thumbFrame = {x=f.x+self.cellPad, y=f.y+self.titleH+self.cellPad, w=self.thumbW, h=self.thumbH}
    local app  = w:application()
    local icon = app and hs.image.imageFromAppBundle(app:bundleID() or '')

    -- cell background; tracks mouse for hover + click
    n = n + 1
    canvas[n] = {
      type = 'rectangle', fillColor = self.cellColor,
      roundedRectRadii = {xRadius=10, yRadius=10},
      frame = {x=f.x+6, y=f.y+6, w=f.w-12, h=f.h-12},
      trackMouseDown = true, trackMouseEnterExit = true,
      id = 'cell:' .. i,
    }
    -- rounded clip for the thumbnail
    n = n + 1
    canvas[n] = {
      type = 'rectangle', action = 'clip',
      roundedRectRadii = {xRadius=8, yRadius=8},
      frame = thumbFrame,
    }
    -- thumbnail: cached snapshot if fresh, else app icon placeholder
    n = n + 1
    canvas[n] = {
      type = 'image',
      image = cachedSnap(w) or icon or hs.image.imageFromName('NSApplicationIcon'),
      imageScaling = 'scaleProportionally',
      frame = thumbFrame,
    }
    imgElem[i] = n
    n = n + 1
    canvas[n] = { type = 'resetClip' }
    -- header: app icon + title above the thumbnail
    local iconS = self.titleH - 6
    if icon then
      n = n + 1
      canvas[n] = {
        type = 'image', image = icon,
        frame = {x = f.x + self.cellPad, y = f.y + 6, w = iconS, h = iconS},
      }
    end
    n = n + 1
    canvas[n] = {
      type = 'text', text = w:title() or '',
      textColor = {white=1, alpha=0.95}, textSize = 12.5,
      textAlignment = 'left', textLineBreak = 'truncateTail',
      frame = {x = f.x + self.cellPad + iconS + 6, y = f.y + 8,
               w = cellW(self) - self.cellPad*2 - iconS - 6, h = self.titleH - 6},
    }
  end

  canvas:mouseCallback(function(_, msg, id, _, _)
    local i = tonumber(tostring(id):match('^cell:(%d+)$'))
    if not i then return end
    if msg == 'mouseEnter' then
      sel = i; drawHighlight(self)
    elseif msg == 'mouseDown' then
      sel = i; closeSwitcher(true)
    end
  end)

  drawHighlight(self)
  canvas:level(hs.canvas.windowLevels.popUpMenu)
  canvas:show()
  asyncRefresh(self)
end

local function allWindows()
  local out = {}
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:isStandard() then out[#out+1] = w end
  end
  return out
end

local function appWindows()
  local app = hs.application.frontmostApplication()
  local out = {}
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:isStandard() and w:application() == app then out[#out+1] = w end
  end
  for _, w in ipairs(app:allWindows()) do
    if w:isStandard() and w:isMinimized() then out[#out+1] = w end
  end
  return out
end

--- GridSwitcher:start()
--- Method
--- Starts the event taps that intercept Cmd+Tab and Option+Tab.
function obj:start()
  local KC_TAB, KC_ESC = hs.keycodes.map['tab'], hs.keycodes.map['escape']

  self._keyTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(ev)
    local kc = ev:getKeyCode()
    if kc == KC_ESC and session then closeSwitcher(false); return true end
    if kc ~= KC_TAB then return false end
    local f = ev:getFlags()

    local kind = nil
    if f.cmd and not f.alt and not f.ctrl then kind = 'cmd'
    elseif f.alt and not f.cmd and not f.ctrl then kind = 'alt' end
    if not kind then return false end

    if session ~= kind then
      closeSwitcher(false)
      local ws = (kind == 'cmd') and allWindows() or appWindows()
      if #ws == 0 then return true end
      session = kind
      showSwitcher(self, ws)
      if f.shift then sel = 1; step(self, -1) end
    else
      step(self, f.shift and -1 or 1)
    end
    return true
  end)
  self._keyTap:start()

  local prevShift = false
  self._flagsTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(ev)
    local f = ev:getFlags()
    if (session == 'cmd' and not f.cmd) or (session == 'alt' and not f.alt) then
      closeSwitcher(true)
      prevShift = f.shift or false
      return false
    end
    if session then
      if f.shift and not prevShift then
        step(self, -1)
        shiftTimer = hs.timer.doAfter(self.shiftDelay, function()
          shiftTimer = hs.timer.doEvery(self.shiftRepeat, function() step(self, -1) end)
        end)
      elseif not f.shift and prevShift then
        if shiftTimer then shiftTimer:stop(); shiftTimer = nil end
      end
    end
    prevShift = f.shift or false
    return false
  end)
  self._flagsTap:start()
  return self
end

--- GridSwitcher:stop()
--- Method
--- Stops the event taps and closes any open switcher.
function obj:stop()
  closeSwitcher(false)
  if self._keyTap   then self._keyTap:stop();   self._keyTap   = nil end
  if self._flagsTap then self._flagsTap:stop(); self._flagsTap = nil end
  return self
end

return obj
